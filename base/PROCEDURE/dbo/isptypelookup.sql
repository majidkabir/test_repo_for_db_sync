SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[ispTypeLookup] 
    @c_Type    NVARCHAR(10),
    @c_String  NVARCHAR(250),
    @b_Success int OUTPUT
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
    DECLARE @n_pos int, 
            @c_String2 NVARCHAR(250)
    -- Remove all the Space
    SELECT @n_POS = 1, @c_String2 = ''
    WHILE @n_pos <= LEN (@c_String)
    BEGIN
       IF SubString(@c_String, @n_pos, 1) <> master.dbo.fnc_GetCharASCII(32) -- space
       BEGIN
          SELECT @c_String2 = dbo.fnc_RTrim(@c_String2) + SubString(@c_String, @n_pos, 1) 
       END
       SELECT @n_pos = @n_pos + 1      
    END
    SELECT @c_String = @c_String2
    -- Remove last char if last char = ,
    IF RIGHT(dbo.fnc_RTrim(@c_String), 1) = ',' 
       SELECT @c_String = SubString(@c_String, 1, LEN(@c_String) -1)
    IF dbo.fnc_RTrim(@c_String) IS NULL 
    BEGIN
       SELECT @b_Success = 0
    END
    ELSE
    BEGIN
       DECLARE @n_StartPos int,
               @n_Length   int
       SELECT @n_pos = 0, @n_StartPos = 1

 		 SELECT type = SPACE(40) Into #Index

       WHILE CharIndex(',', @c_String, @n_StartPos) > 0
       BEGIN
           SELECT @n_pos = CharIndex(',', @c_String, @n_StartPos)
           SELECT @n_Length =  @n_pos - @n_StartPos
           -- select CAST(@c_String AS NVARCHAR(30)), @n_pos '@n_pos', @n_Length '@n_Length', @n_StartPos '@n_StartPos'
           INSERT INTO #index
                SELECT CAST( SubString(@c_String, @n_StartPos, @n_Length ) as NVARCHAR(40) ) 
           SELECT @n_StartPos = @n_pos + 1
       END
       SELECT @n_Length =  LEN(@c_String) - @n_StartPos + 1
       INSERT INTO #index

       SELECT SubString(@c_String, @n_StartPos, @n_Length )
    END
    IF EXISTS (SELECT * FROM #index WHERE Type = @c_Type)
       SELECT @b_success = 1
    ELSE
       SELECT @b_success = 0
 END

GO