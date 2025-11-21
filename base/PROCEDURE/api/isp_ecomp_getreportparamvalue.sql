SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_GetReportParamValue]               */              
/* Creation Date: 20-SEP-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes                                     */
/* 20-SEP-2023    Alex     #JIRA PAC-9 Initial                          */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_GetReportParamValue] (
     @b_Debug                    INT            = 0
   , @c_ReportID                 NVARCHAR(30)   = ''
   , @c_PickSlipNo               NVARCHAR(10)   = ''
   , @c_StorerKey                NVARCHAR(15)   = ''
   , @c_Facility                 NVARCHAR(15)   = ''
   , @n_FromCarton               INT            = 0 
   , @n_ToCarton                 INT            = 0
   , @c_KeyValue1                NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue2                NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue3                NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue4                NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue5                NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue6                NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue7                NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue8                NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue9                NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue10               NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue11               NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue12               NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue13               NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue14               NVARCHAR(60)   = ''  OUTPUT
   , @c_KeyValue15               NVARCHAR(60)   = ''  OUTPUT
   , @b_RecordExists             INT            = 0   OUTPUT                
   , @b_Success                  INT            = 0   OUTPUT
   , @n_ErrNo                    INT            = 0   OUTPUT
   , @c_ErrMsg                   NVARCHAR(250)  = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_SQLQuery           NVARCHAR(MAX)  = ''
         , @c_SQLArgs            NVARCHAR(4000) = ''
         , @c_SQLGroupBy         NVARCHAR(4000) = ''

   DECLARE @n_Continue           INT            = 1
         , @n_StartCnt           INT            = @@TRANCOUNT

         , @n_IsExist            INT            = 0

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
 
         , @n_KeyFieldNo         INT            = 0
         , @n_CtnNoExists        INT            = 0 

   SET @b_RecordExists           = 0

   SELECT @n_IsExist             = (1)
         ,@c_KeyFieldName1       = ISNULL(RH.KeyFieldName1,'')  
         ,@c_KeyFieldName2       = ISNULL(RH.KeyFieldName2,'')  
         ,@c_KeyFieldName3       = ISNULL(RH.KeyFieldName3,'')  
         ,@c_KeyFieldName4       = ISNULL(RH.KeyFieldName4,'')  
         ,@c_KeyFieldName5       = ISNULL(RH.KeyFieldName5,'')  
         ,@c_KeyFieldName6       = ISNULL(RH.KeyFieldName6,'')  
         ,@c_KeyFieldName7       = ISNULL(RH.KeyFieldName7,'')  
         ,@c_KeyFieldName8       = ISNULL(RH.KeyFieldName8,'')  
         ,@c_KeyFieldName9       = ISNULL(RH.KeyFieldName9,'')  
         ,@c_KeyFieldName10      = ISNULL(RH.KeyFieldName10,'')  
         ,@c_KeyFieldName11      = ISNULL(RH.KeyFieldName11,'')  
         ,@c_KeyFieldName12      = ISNULL(RH.KeyFieldName12,'')  
         ,@c_KeyFieldName13      = ISNULL(RH.KeyFieldName13,'')  
         ,@c_KeyFieldName14      = ISNULL(RH.KeyFieldName14,'')  
         ,@c_KeyFieldName15      = ISNULL(RH.KeyFieldName15,'')  
   FROM dbo.WMReport RH(nolock)   
   WHERE ModuleID = 'EPACKING'
   AND ReportID = @c_ReportID

   IF @n_IsExist <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_ErrNo  = 55001
      SET @c_ErrMsg = 'Invalid ReportID - ' + @c_ReportID
   END

   BEGIN TRY
      SET @n_KeyFieldNo = 1
      WHILE @n_KeyFieldNo <= 15
      BEGIN
         SET @c_SQLQuery = 'IF CHARINDEX(''CartonNo'',@c_KeyFieldName' + CONVERT(NVARCHAR(2), @n_KeyFieldNo) + ') > 0 ' + CHAR(13) 
                         + 'BEGIN' + CHAR(13) 
                         + '  IF @n_CtnNoExists > 0 ' + CHAR(13)
                         + '  BEGIN ' + CHAR(13)
                         + '     SET @c_KeyFieldName' + CONVERT(NVARCHAR(2), @n_KeyFieldNo) 
                         + ' = ' 
                         + CASE 
                              WHEN @n_FromCarton > 0 THEN ' CONVERT(NVARCHAR(10), @n_ToCarton) ' 
                              ELSE '''MAX('' + @c_KeyFieldName' + CONVERT(NVARCHAR(2), @n_KeyFieldNo) + ' + '')'' ' 
                           END + CHAR(13)
                         + '  END ' + CHAR(13) 
                         + '  ELSE ' + CHAR(13) 
                         + '  BEGIN ' + CHAR(13)
                         + '     SET @c_KeyFieldName' + CONVERT(NVARCHAR(2), @n_KeyFieldNo) 
                         + ' = ' 
                         + CASE 
                              WHEN @n_FromCarton > 0 THEN ' CONVERT(NVARCHAR(10), @n_FromCarton) ' 
                              ELSE '''MIN('' + @c_KeyFieldName' + CONVERT(NVARCHAR(2), @n_KeyFieldNo) + ' + '')'' ' 
                           END + CHAR(13) 
                         + '     SET @n_CtnNoExists = 1 '  + CHAR(13)
                         + '  END ' + CHAR(13) 
                         + 'END'

         IF @b_Debug = 1
         BEGIN
            PRINT '==============================='
            PRINT '@n_KeyFieldNo' + CONVERT(NVARCHAR(2), @n_KeyFieldNo)
            PRINT '@c_SQLQuery='
            PRINT '-----------'
            PRINT @c_SQLQuery
         END

         SET @c_SQLArgs = '  @n_FromCarton      INT '
                        + ' ,@n_ToCarton        INT '
                        + ' ,@n_CtnNoExists     INT OUTPUT '
                        + ' ,@c_KeyFieldName1   NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName2   NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName3   NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName4   NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName5   NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName6   NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName7   NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName8   NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName9   NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName10  NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName11  NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName12  NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName13  NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName14  NVARCHAR(200) OUTPUT '
                        + ' ,@c_KeyFieldName15  NVARCHAR(200) OUTPUT '

         EXEC sp_ExecuteSql @c_SQLQuery
                           ,@c_SQLArgs
                           ,@n_FromCarton
                           ,@n_ToCarton
                           ,@n_CtnNoExists     OUTPUT
                           ,@c_KeyFieldName1   OUTPUT
                           ,@c_KeyFieldName2   OUTPUT
                           ,@c_KeyFieldName3   OUTPUT
                           ,@c_KeyFieldName4   OUTPUT
                           ,@c_KeyFieldName5   OUTPUT
                           ,@c_KeyFieldName6   OUTPUT
                           ,@c_KeyFieldName7   OUTPUT
                           ,@c_KeyFieldName8   OUTPUT
                           ,@c_KeyFieldName9   OUTPUT
                           ,@c_KeyFieldName10  OUTPUT
                           ,@c_KeyFieldName11  OUTPUT
                           ,@c_KeyFieldName12  OUTPUT
                           ,@c_KeyFieldName13  OUTPUT
                           ,@c_KeyFieldName14  OUTPUT
                           ,@c_KeyFieldName15  OUTPUT

         SET @n_KeyFieldNo = @n_KeyFieldNo + 1
      END

      SET @c_SQLQuery = 'SELECT @b_RecordExists = (1) ' + CHAR(13) 
                      + '      ,@c_KeyValue1 = ' + CASE WHEN @c_KeyFieldName1 = '' THEN '''''' ELSE @c_KeyFieldName1 END + CHAR(13) 
                      + '      ,@c_KeyValue2 = ' + CASE WHEN @c_KeyFieldName2 = '' THEN '''''' ELSE @c_KeyFieldName2 END + CHAR(13) 
                      + '      ,@c_KeyValue3 = ' + CASE WHEN @c_KeyFieldName3 = '' THEN '''''' ELSE @c_KeyFieldName3 END + CHAR(13) 
                      + '      ,@c_KeyValue4 = ' + CASE WHEN @c_KeyFieldName4 = '' THEN '''''' ELSE @c_KeyFieldName4 END + CHAR(13) 
                      + '      ,@c_KeyValue5 = ' + CASE WHEN @c_KeyFieldName5 = '' THEN '''''' ELSE @c_KeyFieldName5 END + CHAR(13) 
                      + '      ,@c_KeyValue6 = ' + CASE WHEN @c_KeyFieldName6 = '' THEN '''''' ELSE @c_KeyFieldName6 END + CHAR(13) 
                      + '      ,@c_KeyValue7 = ' + CASE WHEN @c_KeyFieldName7 = '' THEN '''''' ELSE @c_KeyFieldName7 END + CHAR(13) 
                      + '      ,@c_KeyValue8 = ' + CASE WHEN @c_KeyFieldName8 = '' THEN '''''' ELSE @c_KeyFieldName8 END + CHAR(13) 
                      + '      ,@c_KeyValue9 = ' + CASE WHEN @c_KeyFieldName9 = '' THEN '''''' ELSE @c_KeyFieldName9 END + CHAR(13) 
                      + '      ,@c_KeyValue10 = ' + CASE WHEN @c_KeyFieldName10 = '' THEN '''''' ELSE @c_KeyFieldName10 END + CHAR(13) 
                      + '      ,@c_KeyValue11 = ' + CASE WHEN @c_KeyFieldName11 = '' THEN '''''' ELSE @c_KeyFieldName11 END + CHAR(13) 
                      + '      ,@c_KeyValue12 = ' + CASE WHEN @c_KeyFieldName12 = '' THEN '''''' ELSE @c_KeyFieldName12 END + CHAR(13) 
                      + '      ,@c_KeyValue13 = ' + CASE WHEN @c_KeyFieldName13 = '' THEN '''''' ELSE @c_KeyFieldName13 END + CHAR(13) 
                      + '      ,@c_KeyValue14 = ' + CASE WHEN @c_KeyFieldName14 = '' THEN '''''' ELSE @c_KeyFieldName14 END + CHAR(13) 
                      + '      ,@c_KeyValue15 = ' + CASE WHEN @c_KeyFieldName15 = '' THEN '''''' ELSE @c_KeyFieldName15 END + CHAR(13)
                      + ' FROM dbo.PackHeader PackHeader (NOLOCK)' + CHAR(13) 
                      + ' LEFT OUTER JOIN dbo.PackDetail PackDetail (NOLOCK)' + CHAR(13) 
                      + ' ON (PackDetail.PickSlipNo = @c_PickSlipNo AND PackDetail.PickSlipNo = PackHeader.PickSlipNo AND PackDetail.StorerKey = PackHeader.StorerKey)' + CHAR(13)  
                      + ' LEFT OUTER JOIN dbo.PackInfo PackInfo (NOLOCK)' + CHAR(13) 
                      + ' ON (PackInfo.PickSlipNo = @c_PickSlipNo AND PackInfo.PickSlipNo = PackHeader.PickSlipNo)' + CHAR(13) 
                      + ' WHERE PackHeader.PickSlipNo = @c_PickSlipNo AND PackHeader.StorerKey = @c_StorerKey'
                              
                              
      IF @n_CtnNoExists = 1
      BEGIN
         SET @c_SQLGroupBy = CASE WHEN @c_KeyFieldName1  <> '' AND CHARINDEX('.',@c_KeyFieldName1) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName1) = 0 THEN ', ' + @c_KeyFieldName1 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName2  <> '' AND CHARINDEX('.',@c_KeyFieldName2) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName2) = 0 THEN ', ' + @c_KeyFieldName2 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName3  <> '' AND CHARINDEX('.',@c_KeyFieldName3) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName3) = 0 THEN ', ' + @c_KeyFieldName3 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName4  <> '' AND CHARINDEX('.',@c_KeyFieldName4) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName4) = 0 THEN ', ' + @c_KeyFieldName4 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName5  <> '' AND CHARINDEX('.',@c_KeyFieldName5) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName5) = 0 THEN ', ' + @c_KeyFieldName5 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName6  <> '' AND CHARINDEX('.',@c_KeyFieldName6) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName6) = 0 THEN ', ' + @c_KeyFieldName6 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName7  <> '' AND CHARINDEX('.',@c_KeyFieldName7) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName7) = 0 THEN ', ' + @c_KeyFieldName7 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName8  <> '' AND CHARINDEX('.',@c_KeyFieldName8) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName8) = 0 THEN ', ' + @c_KeyFieldName8 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName9  <> '' AND CHARINDEX('.',@c_KeyFieldName9) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName9) = 0 THEN ', ' + @c_KeyFieldName9 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName10 <> '' AND CHARINDEX('.',@c_KeyFieldName10) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName10) = 0 THEN ', ' + @c_KeyFieldName10 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName11 <> '' AND CHARINDEX('.',@c_KeyFieldName11) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName11) = 0 THEN ', ' + @c_KeyFieldName11 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName12 <> '' AND CHARINDEX('.',@c_KeyFieldName12) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName12) = 0 THEN ', ' + @c_KeyFieldName12 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName13 <> '' AND CHARINDEX('.',@c_KeyFieldName13) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName13) = 0 THEN ', ' + @c_KeyFieldName13 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName14 <> '' AND CHARINDEX('.',@c_KeyFieldName14) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName14) = 0 THEN ', ' + @c_KeyFieldName14 ELSE '' END 
                           + CASE WHEN @c_KeyFieldName15 <> '' AND CHARINDEX('.',@c_KeyFieldName15) > 0 AND CHARINDEX('CartonNo',@c_KeyFieldName15) = 0 THEN ', ' + @c_KeyFieldName15 ELSE '' END 

         IF @c_SQLGroupBy <> ''
         BEGIN
            SET @c_SQLQuery = @c_SQLQuery + CHAR(13) + ' GROUP BY ' + SUBSTRING(@c_SQLGroupBy, 2, LEN(@c_SQLGroupBy))
         END
      END 
  
      SET @c_SQLArgs = '  @b_RecordExists       INT            OUTPUT' 
                     + ', @n_FromCarton         INT '
                     + ', @n_ToCarton           INT '
                     + ', @c_PickSlipNo         NVARCHAR(10)'                                
                     + ', @c_StorerKey          NVARCHAR(15)'                                
                     + ', @c_KeyValue1          NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue2          NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue3          NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue4          NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue5          NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue6          NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue7          NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue8          NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue9          NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue10         NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue11         NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue12         NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue13         NVARCHAR(60)   OUTPUT'                                
                     + ', @c_KeyValue14         NVARCHAR(60)   OUTPUT'  
                     + ', @c_KeyValue15         NVARCHAR(60)   OUTPUT' 

      IF @b_Debug = 1
      BEGIN
         PRINT '==============================='
         PRINT 'Completed STATEMENT'
         PRINT '-----------'
         PRINT @c_SQLQuery
      END                

      EXEC sp_ExecuteSql @c_SQLQuery                            
                       , @c_SQLArgs                  
                       , @b_RecordExists        OUTPUT
                       , @n_FromCarton 
                       , @n_ToCarton   
                       , @c_PickSlipNo                            
                       , @c_StorerKey                            
                       , @c_KeyValue1           OUTPUT                       
                       , @c_KeyValue2           OUTPUT                            
                       , @c_KeyValue3           OUTPUT    
                       , @c_KeyValue4           OUTPUT    
                       , @c_KeyValue5           OUTPUT    
                       , @c_KeyValue6           OUTPUT    
                       , @c_KeyValue7           OUTPUT    
                       , @c_KeyValue8           OUTPUT    
                       , @c_KeyValue9           OUTPUT    
                       , @c_KeyValue10          OUTPUT    
                       , @c_KeyValue11          OUTPUT    
                       , @c_KeyValue12          OUTPUT    
                       , @c_KeyValue13          OUTPUT    
                       , @c_KeyValue14          OUTPUT    
                       , @c_KeyValue15          OUTPUT    
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @n_ErrNo = 55002
      SET @c_ErrMsg = 'Unable to retrieve report key value. ErrMsg: NSQL' + CONVERT(NVARCHAR(10), ERROR_NUMBER()) + ' - ' + ERROR_MESSAGE()
   END CATCH

   QUIT:
   IF @n_Continue= 3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_Success = 0      
      IF @@TRANCOUNT > @n_StartCnt AND @@TRANCOUNT = 1 
      BEGIN               
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END   
      RETURN      
   END      
   ELSE      
   BEGIN      
      SET @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END
END -- Procedure  

GO