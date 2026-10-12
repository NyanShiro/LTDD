using TOEIC.Debugging;

namespace TOEIC;

public class TOEICConsts
{
    public const string LocalizationSourceName = "TOEIC";

    public const string ConnectionStringName = "Default";

    public const bool MultiTenancyEnabled = true;


    /// <summary>
    /// Default pass phrase for SimpleStringCipher decrypt/encrypt operations
    /// </summary>
    public static readonly string DefaultPassPhrase =
        DebugHelper.IsDebug ? "gsKxGZ012HLL3MI5" : "a20a811559c046aa928e09525a9e5003";
}
