SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: [API].[fnc_IsCloseCartonPrintReport]                */
/* Creation Date: 15-AUG-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: Alex                                                     */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: SCEAPI                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes		                                */
/* 15-AUG-2023    Alex     #JIRA PAC-7 Initial                          */
/************************************************************************/

CREATE   FUNCTION [API].[fnc_IsCloseCartonPrintReport]
(  
   @c_ReportID    NVARCHAR(10)
)  
RETURNS BIT 
AS  
BEGIN     
   DECLARE @b_Valid              BIT            = 0
         , @c_ReportType         NVARCHAR(30)   = ''
         , @c_KeyFieldName1      NVARCHAR(200)  = ''
         , @c_KeyFieldName2      NVARCHAR(200)  = ''
         , @c_KeyFieldName3      NVARCHAR(200)  = ''
         , @c_KeyFieldName4      NVARCHAR(200)  = ''
         , @c_KeyFieldName5      NVARCHAR(200)  = ''
         , @c_KeyFieldName6      NVARCHAR(200)  = ''
         , @c_KeyFieldName7      NVARCHAR(200)  = ''
         , @c_KeyFieldName8      NVARCHAR(200)  = ''
         , @c_KeyFieldName9      NVARCHAR(200)  = ''
         , @c_KeyFieldName10     NVARCHAR(200)  = ''
         , @c_KeyFieldName11     NVARCHAR(200)  = ''
         , @c_KeyFieldName12     NVARCHAR(200)  = ''
         , @c_KeyFieldName13     NVARCHAR(200)  = ''
         , @c_KeyFieldName14     NVARCHAR(200)  = ''
         , @c_KeyFieldName15     NVARCHAR(200)  = ''

   SELECT @c_ReportType       = ISNULL(RTRIM(ReportType), '')
         ,@c_KeyFieldName1    = ISNULL(RTRIM(KeyFieldName1), '')
         ,@c_KeyFieldName2    = ISNULL(RTRIM(KeyFieldName2), '')
         ,@c_KeyFieldName3    = ISNULL(RTRIM(KeyFieldName3), '')
         ,@c_KeyFieldName4    = ISNULL(RTRIM(KeyFieldName4), '')
         ,@c_KeyFieldName5    = ISNULL(RTRIM(KeyFieldName5), '')
         ,@c_KeyFieldName6    = ISNULL(RTRIM(KeyFieldName6), '')
         ,@c_KeyFieldName7    = ISNULL(RTRIM(KeyFieldName7), '')
         ,@c_KeyFieldName8    = ISNULL(RTRIM(KeyFieldName8), '')
         ,@c_KeyFieldName9    = ISNULL(RTRIM(KeyFieldName9), '')
         ,@c_KeyFieldName10   = ISNULL(RTRIM(KeyFieldName10), '')
         ,@c_KeyFieldName11   = ISNULL(RTRIM(KeyFieldName11), '')
         ,@c_KeyFieldName12   = ISNULL(RTRIM(KeyFieldName12), '')
         ,@c_KeyFieldName13   = ISNULL(RTRIM(KeyFieldName13), '')
         ,@c_KeyFieldName14   = ISNULL(RTRIM(KeyFieldName14), '')
         ,@c_KeyFieldName15   = ISNULL(RTRIM(KeyFieldName15), '')
   FROM dbo.WMREPORT (NOLOCK) 
   WHERE ReportID = @c_ReportID

   SET @b_Valid = CASE WHEN @c_ReportType IN ('CTNMARKLBL', 'UCCLABEL', 'CTNMNFLBL') AND 
      ( @c_KeyFieldName1 LIKE '%CartonNo%'
      OR @c_KeyFieldName2 LIKE '%CartonNo%'
      OR @c_KeyFieldName3 LIKE '%CartonNo%'
      OR @c_KeyFieldName4 LIKE '%CartonNo%'
      OR @c_KeyFieldName5 LIKE '%CartonNo%'
      OR @c_KeyFieldName6 LIKE '%CartonNo%'
      OR @c_KeyFieldName7 LIKE '%CartonNo%'
      OR @c_KeyFieldName8 LIKE '%CartonNo%'
      OR @c_KeyFieldName9 LIKE '%CartonNo%'
      OR @c_KeyFieldName10 LIKE '%CartonNo%'
      OR @c_KeyFieldName11 LIKE '%CartonNo%'
      OR @c_KeyFieldName12 LIKE '%CartonNo%'
      OR @c_KeyFieldName13 LIKE '%CartonNo%'
      OR @c_KeyFieldName14 LIKE '%CartonNo%'
      OR @c_KeyFieldName15 LIKE '%CartonNo%' ) THEN 1 ELSE 0 END

   EXIT_FUNCTION:   
   RETURN @b_Valid     
END
GO