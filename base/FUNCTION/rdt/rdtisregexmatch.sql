SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE FUNCTION rdt.rdtIsRegExMatch
    (
      @pattern NVARCHAR(2000),
      @matchstring NVARCHAR(MAX)
    )
RETURNS INT
/* The RegexMatch returns True or False, indicating if the regular expression matches (part of) the string. (It returns null if there is an error).
When using this for validating user input, you'll normally want to check if the entire string matches the regular expression. To do so, put a caret at the start of the regex, and a dollar at the end, to anchor the regex at the start and end of the subject string.
*/ 
AS BEGIN
    DECLARE @objRegexExp INT,
        @objErrorObject INT,
        @strErrorMessage NVARCHAR(255),
        @hr INT,
        @match BIT

    SELECT  @strErrorMessage = 'creating a regex object'
    EXEC @hr= sp_OACreate 'VBScript.RegExp', @objRegexExp OUT
    IF @hr = 0 
        EXEC @hr= sp_OASetProperty @objRegexExp, 'Pattern', @pattern
        --Specifying a case-insensitive match 
    IF @hr = 0 
        EXEC @hr= sp_OASetProperty @objRegexExp, 'IgnoreCase', 1
        --Doing a Test' 
    IF @hr = 0 
        EXEC @hr= sp_OAMethod @objRegexExp, 'Test', @match OUT, @matchstring
    IF @hr > 0 
    BEGIN
       RETURN NULL
    END
    EXEC sp_OADestroy @objRegexExp
    RETURN @match
   END

GO