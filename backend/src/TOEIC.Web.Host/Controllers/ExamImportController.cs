using Abp.Authorization;
using Abp.Domain.Uow;
using Abp.EntityFrameworkCore;
using TOEIC.Controllers;
using TOEIC.EntityFrameworkCore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Data;
using System.Data.Common;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace TOEIC.Web.Host.Controllers
{
    [ApiController]
    [Route("api/exams")]
    [AllowAnonymous]
    [IgnoreAntiforgeryToken]
    public class ExamImportController : TOEICControllerBase
    {
        private const int MaxFileSizeBytes = 20 * 1024 * 1024;
        private readonly IDbContextResolver _dbContextResolver;
        private readonly string _connectionString;
        private readonly IWebHostEnvironment _environment;
        private readonly ILogger<ExamImportController> _logger;

        public ExamImportController(
            IDbContextResolver dbContextResolver,
            IConfiguration configuration,
            IWebHostEnvironment environment,
            ILogger<ExamImportController> logger)
        {
            _dbContextResolver = dbContextResolver;
            _connectionString = configuration.GetConnectionString("Default");
            _environment = environment;
            _logger = logger;
        }

        [HttpGet]
        [UnitOfWork]
        public async Task<IActionResult> Get()
        {
            var dbContext = _dbContextResolver.Resolve<TOEICDbContext>(_connectionString, null);
            var connection = dbContext.Database.GetDbConnection();
            var closeConnection = connection.State != ConnectionState.Open;
            if (closeConnection)
            {
                await connection.OpenAsync();
            }

            try
            {
                using (var command = connection.CreateCommand())
                {
                    command.CommandText = @"
SELECT e.Id, e.Title, e.Subject, e.Code, e.DurationMinutes, e.CreationTime,
       q.QuestionNumber, q.QuestionText, q.OptionA, q.OptionB, q.OptionC, q.OptionD, q.CorrectAnswer
FROM Exams e
LEFT JOIN ExamQuestions q ON q.ExamId = e.Id AND q.IsDeleted = 0
WHERE e.IsPublished = 1 AND e.IsDeleted = 0
ORDER BY e.Id DESC, q.QuestionNumber";

                    var exams = new Dictionary<int, ExamResponse>();
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            var id = reader.GetInt32(0);
                            ExamResponse exam;
                            if (!exams.TryGetValue(id, out exam))
                            {
                                exam = new ExamResponse
                                {
                                    Id = id,
                                    Title = reader.GetString(1),
                                    Subject = reader.GetString(2),
                                    Code = reader.GetString(3),
                                    DurationMinutes = reader.IsDBNull(4) ? 0 : reader.GetInt32(4),
                                    CreationTime = reader.GetDateTime(5),
                                    Questions = new List<ExamQuestionResponse>()
                                };
                                exams.Add(id, exam);
                            }

                            if (!reader.IsDBNull(6))
                            {
                                exam.Questions.Add(new ExamQuestionResponse
                                {
                                    Number = reader.GetInt32(6),
                                    Prompt = reader.GetString(7),
                                    OptionA = reader.GetString(8),
                                    OptionB = reader.GetString(9),
                                    OptionC = reader.GetString(10),
                                    OptionD = reader.GetString(11),
                                    CorrectOption = reader.GetString(12)
                                });
                            }
                        }
                    }

                    return Ok(exams.Values.ToList());
                }
            }
            finally
            {
                if (closeConnection)
                {
                    connection.Close();
                }
            }
        }

        [HttpPost("import")]
        [RequestSizeLimit(32 * 1024 * 1024)]
        [UnitOfWork]
        public async Task<IActionResult> Import([FromBody] ImportExamRequest input)
        {
            if (input.Questions == null || input.Questions.Count == 0)
            {
                return BadRequest(new { message = "Đề thi phải có ít nhất một câu hỏi." });
            }
            if (input.DurationMinutes < 1 || input.DurationMinutes > 600)
            {
                return BadRequest(new { message = "Thời lượng đề thi phải từ 1 đến 600 phút." });
            }

            byte[] fileBytes;
            try
            {
                fileBytes = Convert.FromBase64String(input.FileBase64);
            }
            catch (FormatException)
            {
                return BadRequest(new { message = "Nội dung file Word không hợp lệ." });
            }

            if (fileBytes.Length == 0 || fileBytes.Length > MaxFileSizeBytes)
            {
                return BadRequest(new { message = "File Word phải có dung lượng tối đa 20 MB." });
            }

            var firstQuestionNumber = input.Questions[0].Number;
            for (var index = 0; index < input.Questions.Count; index++)
            {
                var question = input.Questions[index];
                if (question.Number != firstQuestionNumber + index ||
                    string.IsNullOrWhiteSpace(question.Prompt) ||
                    string.IsNullOrWhiteSpace(question.OptionA) ||
                    string.IsNullOrWhiteSpace(question.OptionB) ||
                    string.IsNullOrWhiteSpace(question.OptionC) ||
                    string.IsNullOrWhiteSpace(question.OptionD) ||
                    !new[] { "A", "B", "C", "D" }.Contains(question.CorrectOption))
                {
                    return BadRequest(new
                    {
                        message = "Câu hỏi cần liên tục, đủ nội dung A-D và có đáp án đúng hợp lệ."
                    });
                }
            }

            var originalFileName = Path.GetFileName(input.OriginalFileName);
            if (originalFileName.Length > 255)
            {
                originalFileName = originalFileName.Substring(originalFileName.Length - 255);
            }

            var fileName = Guid.NewGuid().ToString("N") + ".docx";
            var relativeFilePath = Path.Combine("App_Data", "Exams", fileName);
            var absoluteFilePath = Path.Combine(_environment.ContentRootPath, relativeFilePath);
            var dbContext = _dbContextResolver.Resolve<TOEICDbContext>(_connectionString, null);
            var connection = dbContext.Database.GetDbConnection();
            var closeConnection = connection.State != ConnectionState.Open;

            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(absoluteFilePath));
                await System.IO.File.WriteAllBytesAsync(absoluteFilePath, fileBytes);
                if (closeConnection)
                {
                    await connection.OpenAsync();
                }

                var transaction = dbContext.Database.CurrentTransaction;
                var ownsTransaction = transaction == null;
                if (ownsTransaction)
                {
                    transaction = await dbContext.Database.BeginTransactionAsync();
                }

                try
                {
                    var databaseTransaction = transaction.GetDbTransaction();
                    int examId;
                    using (var command = connection.CreateCommand())
                    {
                        command.Transaction = databaseTransaction;
                        command.CommandText = @"
INSERT INTO Exams
    (Title, Subject, Code, OriginalFileName, FilePath, TotalQuestions,
     DurationMinutes, IsPublished, CreationTime, IsDeleted)
VALUES
    (@Title, @Subject, @Code, @OriginalFileName, @FilePath, @TotalQuestions,
     @DurationMinutes, 1, @CreationTime, 0);
SELECT CAST(SCOPE_IDENTITY() AS int);";
                        AddParameter(command, "@Title", input.Title.Trim());
                        AddParameter(command, "@Subject", input.Subject.Trim());
                        AddParameter(command, "@Code", input.Code.Trim());
                        AddParameter(command, "@OriginalFileName", originalFileName);
                        AddParameter(command, "@FilePath", relativeFilePath);
                        AddParameter(command, "@TotalQuestions", input.Questions.Count);
                        AddParameter(command, "@DurationMinutes", input.DurationMinutes);
                        AddParameter(command, "@CreationTime", DateTime.UtcNow);
                        examId = Convert.ToInt32(await command.ExecuteScalarAsync());
                    }

                    foreach (var question in input.Questions)
                    {
                        using (var command = connection.CreateCommand())
                        {
                            command.Transaction = databaseTransaction;
                            command.CommandText = @"
INSERT INTO ExamQuestions
    (ExamId, QuestionNumber, QuestionText, OptionA, OptionB, OptionC, OptionD,
     CorrectAnswer, CreationTime, IsDeleted)
VALUES
    (@ExamId, @QuestionNumber, @QuestionText, @OptionA, @OptionB, @OptionC, @OptionD,
     @CorrectAnswer, @CreationTime, 0);";
                            AddParameter(command, "@ExamId", examId);
                            AddParameter(command, "@QuestionNumber", question.Number);
                            AddParameter(command, "@QuestionText", question.Prompt);
                            AddParameter(command, "@OptionA", question.OptionA);
                            AddParameter(command, "@OptionB", question.OptionB);
                            AddParameter(command, "@OptionC", question.OptionC);
                            AddParameter(command, "@OptionD", question.OptionD);
                            AddParameter(command, "@CorrectAnswer", question.CorrectOption);
                            AddParameter(command, "@CreationTime", DateTime.UtcNow);
                            await command.ExecuteNonQueryAsync();
                        }
                    }

                    if (ownsTransaction)
                    {
                        await transaction.CommitAsync();
                    }
                    return Ok(new { id = examId, message = "Đã lưu đề thi vào database." });
                }
                catch
                {
                    if (ownsTransaction)
                    {
                        await transaction.RollbackAsync();
                    }
                    throw;
                }
                finally
                {
                    if (ownsTransaction)
                    {
                        transaction.Dispose();
                    }
                }
            }
            catch (Exception exception)
            {
                _logger.LogError(exception, "Could not persist imported exam {ExamCode}.", input.Code);
                if (System.IO.File.Exists(absoluteFilePath))
                {
                    System.IO.File.Delete(absoluteFilePath);
                }
                return StatusCode(500, new { message = "Không thể lưu đề thi vào database." });
            }
            finally
            {
                if (closeConnection)
                {
                    connection.Close();
                }
            }
        }

        private static void AddParameter(DbCommand command, string name, object value)
        {
            var parameter = command.CreateParameter();
            parameter.ParameterName = name;
            parameter.Value = value ?? DBNull.Value;
            command.Parameters.Add(parameter);
        }
    }

    public class ImportExamRequest
    {
        [Required, StringLength(255)]
        public string Title { get; set; }

        [Required, StringLength(255)]
        public string Subject { get; set; }

        [Required, StringLength(100)]
        public string Code { get; set; }

        [Range(1, 600)]
        public int DurationMinutes { get; set; }

        [Required, StringLength(255)]
        public string OriginalFileName { get; set; }

        [Required]
        public string FileBase64 { get; set; }

        [Required]
        public List<ImportExamQuestionRequest> Questions { get; set; }
    }

    public class ImportExamQuestionRequest
    {
        public int Number { get; set; }

        [Required]
        public string Prompt { get; set; }

        [Required]
        public string OptionA { get; set; }

        [Required]
        public string OptionB { get; set; }

        [Required]
        public string OptionC { get; set; }

        [Required]
        public string OptionD { get; set; }

        [Required, StringLength(1)]
        public string CorrectOption { get; set; }
    }

    public class ExamResponse
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Subject { get; set; }
        public string Code { get; set; }
        public int DurationMinutes { get; set; }
        public DateTime CreationTime { get; set; }
        public List<ExamQuestionResponse> Questions { get; set; }
    }

    public class ExamQuestionResponse
    {
        public int Number { get; set; }
        public string Prompt { get; set; }
        public string OptionA { get; set; }
        public string OptionB { get; set; }
        public string OptionC { get; set; }
        public string OptionD { get; set; }
        public string CorrectOption { get; set; }
    }
}