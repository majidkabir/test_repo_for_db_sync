SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE FUNCTION [dbo].[fnc_GetVC_OperatorID] 
  ( 
    @c_MessageText  NVARCHAR(4000)
  )
RETURNS NVARCHAR(20)
AS
BEGIN
   DECLARE @c_Delim CHAR(1)
          ,@n_SeqNo INT  
          ,@c_OperatorID NVARCHAR(20)
          
   DECLARE @t_MessageRec TABLE (Seqno INT ,ColValue NVARCHAR(215))  
   DECLARE @n_StartPos INT, @n_EndPos INT ,@c_Parms NVARCHAR(4000)
      
   SET @n_StartPos = CHARINDEX('(', @c_MessageText) 
   SET @n_EndPos = CHARINDEX(')', @c_MessageText) 

   SET @c_Parms = REPLACE(SUBSTRING(@c_MessageText, @n_StartPos + 1, (@n_EndPos - @n_StartPos) -1) ,'''','') 

   SET @c_Delim = ','
   
   INSERT INTO @t_MessageRec
   SELECT *
   FROM   dbo.fnc_DelimSplit(@c_Delim ,@c_Parms)  
   
  
   SELECT @c_OperatorID = ColValue
   FROM   @t_MessageRec 
   WHERE Seqno = 3
    
   --SELECT * FROM @t_MessageRec
   RETURN @c_OperatorID
END

GO