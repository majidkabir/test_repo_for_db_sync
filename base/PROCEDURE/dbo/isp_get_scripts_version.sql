SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Get_Scripts_Version                            */
/* Creation Date: 15-Jan-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by:wtshong                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GIT Version: 1.0                                                     */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* 15-Jan-2021    1.0      Initial Version								      */
/* 25-Jan-2021    1.1      Enhancement                                  */
/************************************************************************/
CREATE PROC  [dbo].[isp_Get_Scripts_Version]
AS
BEGIN
   SET NOCOUNT ON

   DECLARE @n_DB_ID                  INT
          ,@c_Linked_Server_Name     VARCHAR(50)
          ,@c_DB_Name                VARCHAR(50)
          ,@c_SQL                    NVARCHAR(4000)
          ,@c_Parms                  NVARCHAR(1000)

          
   DECLARE @cSchema             NVARCHAR(50)
          ,@cObjName            NVARCHAR(255)
          ,@cObjType            NVARCHAR(10)
          ,@bWithComments       BIT=0
          ,@cLastModifyDate     NVARCHAR(12)=''
          ,@cParseDate          NVARCHAR(12)=''
          ,@objCreateDate       DATETIME
          ,@objModifyDate       DATETIME 
          ,@cCombineName        NVARCHAR(255)           

   IF OBJECT_ID('tempdb..#OBJECTS') IS NOT NULL
      DROP TABLE #OBJECTS

   CREATE TABLE #OBJECTS (
    ObjType   NVARCHAR(10),
    ObjSchema NVARCHAR(20), 
    ObjName   NVARCHAR(100),
    ObjCreateDate DATETIME,
    ObjModifyDate DATETIME,
    LastModify NVARCHAR(12), 
    WithComment Bit 
   )
   
         
   DECLARE CUR_OBJECTS CURSOR FAST_FORWARD READ_ONLY FOR 
    SELECT o.name, s.name, o.type, o.create_date, o.modify_date 
    FROM sys.objects o
    JOIN sys.schemas s on s.schema_id = o.schema_id 
    WHERE type in ('P', 'TR', 'FN')  
    AND O.name not in ('fnc_DecryptPWD') 
    AND S.name not in ('BI') 
    AND O.is_ms_shipped = 0

    OPEN CUR_OBJECTS

    FETCH NEXT FROM CUR_OBJECTS INTO @cObjName, @cSchema, @cObjType, @objCreateDate, @objModifyDate  
    WHILE @@FETCH_STATUS = 0 
    BEGIN
      SET @bWithComments = 0 
      SET @cLastModifyDate = ''                  

      SET @cCombineName = QUOTENAME(@cSchema) + '.' + QUOTENAME(@cObjName)

      EXEC dbo.sp_GetLastModifyDate @objname = @cCombineName, @bWithComments = @bWithComments OUTPUT, @cLastModifyDate = @cLastModifyDate OUTPUT
      
      SET @cParseDate = ''
      IF @cLastModifyDate > ''
      BEGIN         
         BEGIN TRY
            SELECT @cParseDate = PARSE(@cLastModifyDate AS DATE)
         END TRY
         BEGIN CATCH
            SET @cParseDate = @cLastModifyDate
         END CATCH                  
      END
           
      INSERT INTO #OBJECTS
      (
         ObjType,
         ObjSchema,
         ObjName,
         ObjCreateDate,
         ObjModifyDate,
         LastModify,
         WithComment
      )
      VALUES
      (
         @cObjType,
         @cSchema,
         @cObjName,
         @objCreateDate,
         @objModifyDate,
         @cLastModifyDate,
         @bWithComments 
      )

      FETCH NEXT FROM CUR_OBJECTS INTO @cObjName, @cSchema, @cObjType, @objCreateDate, @objModifyDate     
   END 
   CLOSE CUR_OBJECTS
   DEALLOCATE CUR_OBJECTS 
   
   SELECT * FROM #OBJECTS AS o WITH(NOLOCK)
END

GO