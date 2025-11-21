SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function: fnc_GetLangMsgText                                         */
/* Creation Date: 2022-11-11                                            */
/* Copyright: LF Logistics/Maersk                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-21150 - [CN] Nike_Ecom Packing_Chinesization            */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-11-11  Wan      1.0   Created & DevOps Combine Script           */
/* 2023-03-01  Wan01    1.1   WMS-21512 - [CN] NIKE_NFC_RFID_ECOMPACKING*/
/*                            _CR_V1.0                                  */
/************************************************************************/
CREATE   FUNCTION [dbo].[fnc_GetLangMsgText] 
(  @c_MsgId          NVARCHAR(40)
,  @c_MsgText        NVARCHAR(255)
,  @c_Parms          NVARCHAR(255)
)
RETURNS NVARCHAR(255) AS
BEGIN
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF

   DECLARE @n_MsgLangID          INT = 1
         , @c_Language           NVARCHAR(30) = 'ENGLISH'
   
   DECLARE @t_Subsitute          TABLE 
      (  RowID    INT            IDENTITY(1,1)  PRIMARY KEY
      ,  Parm     NVARCHAR(100)  NOT NULL DEFAULT('')
      )
      
   DECLARE @t_SplitMsg           TABLE 
      (  RowID    INT            IDENTITY(1,1)  PRIMARY KEY
      ,  MsgText  NVARCHAR(255)  NOT NULL DEFAULT('')
      )   
      
   SELECT @c_Language = IIF(n.NSQLValue = '', n.NSQLValue, @c_Language)
   FROM dbo.NSQLCONFIG AS n WITH (NOLOCK)
   WHERE n.Configkey = 'Language'
   
   SELECT TOP 1 @n_MsgLangID = c.Code
   FROM dbo.CODELKUP AS c WITH (NOLOCK)
   WHERE c.LISTNAME = 'Language'
   AND c.[Description] LIKE @c_Language + '%'
   
   SELECT TOP 1 @c_MsgText = mt.MsgText
   FROM dbo.MESSAGE_ID AS mi WITH (NOLOCK)
   JOIN dbo.MESSAGE_TEXT AS mt WITH (NOLOCK) ON mt.MsgId = mi.MsgId
   WHERE mi.MsgId = @c_MsgID
   ORDER BY IIF(mt.MsgLangId = @n_MsgLangID, 1, 9)
          , mt.MsgLangId
          
   IF CHARINDEX('%s', @c_MsgText) > 0 AND RTRIM(@c_Parms) <> '' 
   BEGIN
      IF LEFT(@c_Parms,1) = '|'                                                           --(Wan01)
      BEGIN
         SET @c_Parms = SUBSTRING(@c_Parms, 2, LEN(@c_Parms) - 1)
      END
      
      SET @c_MsgText = REPLACE(@c_MsgText, '%s','%s|')
      
      INSERT INTO @t_SplitMsg (MsgText)
      SELECT SplitMsgText = s.[Value] 
      FROM STRING_SPLIT(@c_MsgText, '|') AS s
      
      INSERT INTO @t_Subsitute ( Parm )
      SELECT Parm = LTRIM(RTRIM(s.[Value])) 
      FROM STRING_SPLIT(@c_Parms, '|') AS s
      
      SELECT @c_MsgText = STRING_AGG(REPLACE(tsm.MsgText, '%s', ISNULL(ts.Parm,'')), '')  --(Wan01)
      WITHIN GROUP (ORDER BY tsm.RowID ASC)
      FROM @t_SplitMsg AS tsm
      LEFT OUTER JOIN @t_Subsitute AS ts ON ts.RowID = tsm.RowID
      WHERE tsm.RowID IS NOT NULL
   END       
                    
   RETURN @c_MsgText
END -- procedure

GO