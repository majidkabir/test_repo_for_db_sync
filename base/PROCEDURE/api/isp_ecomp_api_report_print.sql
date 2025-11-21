SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_Report_Print]                  */              
/* Creation Date: 12-May-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: Allen                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: SCE_API                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes										*/
/* 12-May-2023    Allen     #JIRA PAC-65 Initial                        */
/* 04-Sep-2023    Allen     #JIRA PAC-129 Add defalut printer   --(AL02)*/
/* 03-JAN-2024    Alex01   #JIRA PAC-176 Pass ComputerName to Print SP  */
/* 14-MAY-2024    Alex02   #JIRA PAC-341 LogiReport Printing            */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_API_Report_Print](
     @b_Debug           INT            = 0
   , @c_Format          VARCHAR(10)    = ''
   , @c_UserID          NVARCHAR(256)  = ''
   , @c_OperationType   NVARCHAR(60)   = ''
   , @c_RequestString   NVARCHAR(MAX)  = ''
   , @b_Success         INT            = 0   OUTPUT
   , @n_ErrNo           INT            = 0   OUTPUT
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT
   , @c_ResponseString  NVARCHAR(MAX)  = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT            = 1
         , @n_StartCnt                    INT            = @@TRANCOUNT

         , @c_ComputerName                NVARCHAR(30)   = ''

         , @c_PickSlipNo                  NVARCHAR(10)   = ''

         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_Facility                    NVARCHAR(15)   = ''

         , @c_ReportID                    NVARCHAR(10)   = ''
         --, @c_PrintType                   NVARCHAR(10)   = ''
         , @n_NoOfCopy                    INT            = 1
         , @c_IsPaperPrinter              NVARCHAR(1)    = ''
         , @c_PrintType                   NVARCHAR(10)   = ''

         , @c_KeyFieldName1               NVARCHAR(200)  = ''
         , @c_KeyFieldName2               NVARCHAR(200)  = ''
         , @c_KeyFieldName3               NVARCHAR(200)  = ''
         , @c_KeyFieldName4               NVARCHAR(200)  = ''
         , @c_KeyFieldName5               NVARCHAR(200)  = ''
         , @c_KeyFieldName6               NVARCHAR(200)  = ''
         , @c_KeyFieldName7               NVARCHAR(200)  = ''
         , @c_KeyFieldName8               NVARCHAR(200)  = ''
         , @c_KeyFieldName9               NVARCHAR(200)  = ''
         , @c_KeyFieldName10              NVARCHAR(200)  = ''
         , @c_KeyFieldName11              NVARCHAR(200)  = ''
         , @c_KeyFieldName12              NVARCHAR(200)  = ''
         , @c_KeyFieldName13              NVARCHAR(200)  = ''
         , @c_KeyFieldName14              NVARCHAR(200)  = ''
         , @c_KeyFieldName15              NVARCHAR(200)  = ''
         , @c_KeyValue1                   NVARCHAR(60)   = ''
         , @c_KeyValue2                   NVARCHAR(60)   = ''
         , @c_KeyValue3                   NVARCHAR(60)   = ''
         , @c_KeyValue4                   NVARCHAR(60)   = ''
         , @c_KeyValue5                   NVARCHAR(60)   = ''
         , @c_KeyValue6                   NVARCHAR(60)   = ''
         , @c_KeyValue7                   NVARCHAR(60)   = ''
         , @c_KeyValue8                   NVARCHAR(60)   = ''
         , @c_KeyValue9                   NVARCHAR(60)   = ''
         , @c_KeyValue10                  NVARCHAR(60)   = ''
         , @c_KeyValue11                  NVARCHAR(60)   = ''
         , @c_KeyValue12                  NVARCHAR(60)   = ''
         , @c_KeyValue13                  NVARCHAR(60)   = ''
         , @c_KeyValue14                  NVARCHAR(60)   = ''
         , @c_KeyValue15                  NVARCHAR(60)   = ''
         , @c_PrinterID                   NVARCHAR(30)   = ''
         , @c_JobIDs                      NVARCHAR(50)   = ''
         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)  = ''
         , @c_ExecStatements              NVARCHAR(max)  = ''
         , @c_ExecArguments               NVARCHAR(max)  = ''

         , @c_PrintSource                 NVARCHAR(10)   = 'WMReport'   --(Alex02)

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''

   --Change Login User
   SET @n_sp_err = 0     
   EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserID OUTPUT, @n_Err = @n_sp_err OUTPUT, @c_ErrMsg = @c_sp_errmsg OUTPUT    
       
   EXECUTE AS LOGIN = @c_UserID    
       
   IF @n_sp_err <> 0     
   BEGIN      
      SET @n_Continue = 3      
      SET @n_ErrNo = @n_sp_err      
      SET @c_ErrMsg = @c_sp_errmsg     
      GOTO QUIT      
   END  

   SELECT @c_StorerKey        = ISNULL(RTRIM(StorerKey      ), '')
         ,@c_Facility         = ISNULL(RTRIM(Facility    ), '')
         ,@c_ComputerName     = ISNULL(RTRIM(ComputerName), '')
         ,@c_ReportID         = ISNULL(RTRIM(ReportID), '')
         ,@n_NoOfCopy         = ISNULL(NoOfCopy, 1)
         ,@c_IsPaperPrinter   = ISNULL(RTRIM(IsPaperPrinter), '')
         ,@c_PrinterID        = ISNULL(RTRIM(PrinterID), '')
         --,@c_PrintType        = ISNULL(RTRIM(PrintType), '')
         ,@c_KeyValue1        = ISNULL(RTRIM(KeyValue1), '')
         ,@c_KeyValue2        = ISNULL(RTRIM(KeyValue2), '')
         ,@c_KeyValue3        = ISNULL(RTRIM(KeyValue3), '')
         ,@c_KeyValue4        = ISNULL(RTRIM(KeyValue4), '')
         ,@c_KeyValue5        = ISNULL(RTRIM(KeyValue5), '')
         ,@c_KeyValue6        = ISNULL(RTRIM(KeyValue6), '')
         ,@c_KeyValue7        = ISNULL(RTRIM(KeyValue7), '')
         ,@c_KeyValue8        = ISNULL(RTRIM(KeyValue8), '')
         ,@c_KeyValue9        = ISNULL(RTRIM(KeyValue9), '')
         ,@c_KeyValue10       = ISNULL(RTRIM(KeyValue10), '')
         ,@c_KeyValue11       = ISNULL(RTRIM(KeyValue11), '')
         ,@c_KeyValue12       = ISNULL(RTRIM(KeyValue12), '')
         ,@c_KeyValue13       = ISNULL(RTRIM(KeyValue13), '')
         ,@c_KeyValue14       = ISNULL(RTRIM(KeyValue14), '')
         ,@c_KeyValue15       = ISNULL(RTRIM(KeyValue15), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      StorerKey         NVARCHAR(15)         '$.StorerKey',
      Facility          NVARCHAR(15)         '$.Facility',
      ComputerName      NVARCHAR(30)         '$.ComputerName',  
      ReportID          NVARCHAR(10)         '$.ReportID',
      NoOfCopy          INT                  '$.NoOfCopy',
      IsPaperPrinter    NVARCHAR(1)          '$.IsPaperPrinter',
      PrinterID         NVARCHAR(30)         '$.PrinterID',
      --PrintType         NVARCHAR(30)         '$.PrintType',
      KeyValue1         NVARCHAR(60)         '$.KeyValue1',
      KeyValue2         NVARCHAR(60)         '$.KeyValue2',
      KeyValue3         NVARCHAR(60)         '$.KeyValue3',
      KeyValue4         NVARCHAR(60)         '$.KeyValue4',
      KeyValue5         NVARCHAR(60)         '$.KeyValue5',
      KeyValue6         NVARCHAR(60)         '$.KeyValue6',
      KeyValue7         NVARCHAR(60)         '$.KeyValue7',
      KeyValue8         NVARCHAR(60)         '$.KeyValue8',
      KeyValue9         NVARCHAR(60)         '$.KeyValue9',
      KeyValue10        NVARCHAR(60)         '$.KeyValue10',
      KeyValue11        NVARCHAR(60)         '$.KeyValue11',
      KeyValue12        NVARCHAR(60)         '$.KeyValue12',
      KeyValue13        NVARCHAR(60)         '$.KeyValue13',
      KeyValue14        NVARCHAR(60)         '$.KeyValue14',
      KeyValue15        NVARCHAR(60)         '$.KeyValue15'
   )

   IF @b_Debug = 1
   BEGIN
      PRINT '@c_StorerKey     : ' + @c_StorerKey      
      PRINT '@c_Facility      : ' + @c_Facility        
      PRINT '@c_ComputerName  : ' + @c_ComputerName    
      --PRINT '@c_PrintType     : ' + @c_PrintType      
      PRINT '@c_ReportID      : ' + @c_ReportID        
      PRINT '@n_NoOfCopy      : ' + CONVERT(NVARCHAR, @n_NoOfCopy)
      PRINT '@c_PrinterID     : ' + @c_PrinterID
      PRINT '@c_IsPaperPrinter: ' + @c_IsPaperPrinter  
      PRINT '@c_KeyValue1     : ' + @c_KeyValue1       
      PRINT '@c_KeyValue2     : ' + @c_KeyValue2       
      PRINT '@c_KeyValue3     : ' + @c_KeyValue3       
      PRINT '@c_KeyValue4     : ' + @c_KeyValue4       
      PRINT '@c_KeyValue5     : ' + @c_KeyValue5       
      PRINT '@c_KeyValue6     : ' + @c_KeyValue6       
      PRINT '@c_KeyValue7     : ' + @c_KeyValue7       
      PRINT '@c_KeyValue8     : ' + @c_KeyValue8       
      PRINT '@c_KeyValue9     : ' + @c_KeyValue9       
      PRINT '@c_KeyValue10    : ' + @c_KeyValue10      
      PRINT '@c_KeyValue11    : ' + @c_KeyValue11      
      PRINT '@c_KeyValue12    : ' + @c_KeyValue12      
      PRINT '@c_KeyValue13    : ' + @c_KeyValue13      
      PRINT '@c_KeyValue14    : ' + @c_KeyValue14      
      PRINT '@c_KeyValue15    : ' + @c_KeyValue15      
   END

   IF @c_ReportID <> ''
   BEGIN
      SET @b_sp_Success = 0
      SET @n_sp_err     = 0
      SET @c_sp_errmsg  = ''
      
      --(Alex02) Begin
      SET @c_PrintSource = 'WMReport'

      SELECT @c_PrintSource      = CASE 
                                     WHEN  ISNULL(RTRIM(PrintType),'') = 'LOGIReport' THEN 'JReport' 
                                     ELSE 'WMReport'
                                   END
      FROM [dbo].[WMREPORTDETAIL] (NOLOCK) 
      WHERE ReportID = @c_ReportID
      AND StorerKey = @c_StorerKey
      AND ISNULL(Facility,'') IN('',@c_Facility)  


      --(Alex02) End
      --IF @c_PrintType = 'TCPSPooler'
      --BEGIN
      --    SELECT @c_PrinterID = ISNULL(DefaultPrinter_Paper,'') FROM RDT.RDTUser(NOLOCK) WHERE UserName = @c_UserID
      --END
      --ELSE IF @c_PrintType = 'Bartender'
      --BEGIN
      --    SELECT @c_PrinterID = ISNULL(DefaultPrinter,'') FROM RDT.RDTUser(NOLOCK) WHERE UserName = @c_UserID
      --END
      --ELSE --(AL02) -S
      --BEGIN
      --   SELECT @c_PrinterID = ISNULL(DefaultPrinter_Paper,'') FROM RDT.RDTUser(NOLOCK) WHERE UserName = @c_UserID
      --END --(AL02) -E
      --IF @b_Debug = 1
      --BEGIN
      --   PRINT '@c_PrinterID      : ' + @c_PrinterID        
      --   PRINT '@c_UserID      : ' + @c_UserID        
      --END

      EXEC [WM].[lsp_WM_Print_Report] @c_ModuleID           = N'EPACKING',                -- nvarchar(30)
                                      @c_ReportID           = @c_ReportID,                -- nvarchar(10)
                                      @c_Storerkey          = @c_StorerKey,               -- nvarchar(15)
                                      @c_Facility           = @c_Facility,                -- nvarchar(5)
                                      @c_UserName           = @c_UserID,                  -- nvarchar(128)
                                      @c_ComputerName       = @c_ComputerName,            -- nvarchar(30)  --Alex01
                                      @c_PrinterID          = @c_PrinterID,               -- nvarchar(30)
                                      @n_NoOfCopy           = @n_NoOfCopy,                -- int
                                      @c_IsPaperPrinter     = @c_IsPaperPrinter,          -- nchar(1)
                                      @c_KeyValue1          = @c_KeyValue1,               -- nvarchar(60)
                                      @c_KeyValue2          = @c_KeyValue2,               -- nvarchar(60)
                                      @c_KeyValue3          = @c_KeyValue3,               -- nvarchar(60)
                                      @c_KeyValue4          = @c_KeyValue4,               -- nvarchar(60)
                                      @c_KeyValue5          = @c_KeyValue5,               -- nvarchar(60)
                                      @c_KeyValue6          = @c_KeyValue6,               -- nvarchar(60)
                                      @c_KeyValue7          = @c_KeyValue7,               -- nvarchar(60)
                                      @c_KeyValue8          = @c_KeyValue8,               -- nvarchar(60)
                                      @c_KeyValue9          = @c_KeyValue9,               -- nvarchar(60)
                                      @c_KeyValue10         = @c_KeyValue10,              -- nvarchar(60)
                                      @c_KeyValue11         = @c_KeyValue11,              -- nvarchar(60)
                                      @c_KeyValue12         = @c_KeyValue12,              -- nvarchar(60)
                                      @c_KeyValue13         = @c_KeyValue13,              -- nvarchar(60)
                                      @c_KeyValue14         = @c_KeyValue14,              -- nvarchar(60)
                                      @c_KeyValue15         = @c_KeyValue15,              -- nvarchar(60)
                                      @c_ExtendedParmValue1 = N'',                        -- nvarchar(60)
                                      @c_ExtendedParmValue2 = N'',                        -- nvarchar(60)
                                      @c_ExtendedParmValue3 = N'',                        -- nvarchar(60)
                                      @c_ExtendedParmValue4 = N'',                        -- nvarchar(60)
                                      @c_ExtendedParmValue5 = N'',                        -- nvarchar(60)
                                      @b_Success            = @b_sp_Success   OUTPUT,     -- int
                                      @n_Err                = @n_sp_err       OUTPUT,     -- int
                                      @c_ErrMsg             = @c_sp_errmsg    OUTPUT,     -- nvarchar(255)
                                      @c_PrintSource        = @c_PrintSource,             -- nvarchar(10)            --(Alex02)
                                      @b_SCEPreView         = 0,                          -- int
                                      @c_JobIDs             = @c_JobIDs       OUTPUT,     -- nvarchar(50)
                                      @c_AutoPrint          = N'N'                         -- nvarchar(1)
      IF @b_Debug = 1
      BEGIN
         PRINT '@b_sp_Success      : ' + CONVERT(NVARCHAR, @b_sp_Success)
         PRINT '@n_sp_err      : ' + CONVERT(NVARCHAR, @n_sp_err)
         PRINT '@c_sp_errmsg      : ' + @c_sp_errmsg    
         PRINT '@c_JobIDs      : ' + @c_JobIDs        
      END
      IF @b_sp_Success <> 1
      BEGIN
         SET @n_Continue = 3      
         SET @n_ErrNo = 51900      
         SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                       + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
         GOTO QUIT  
      END
   END

   IF @b_Debug = 1
   BEGIN
      PRINT '@c_JobIDs      : ' + @c_JobIDs        
   END

   SET @c_ResponseString = ISNULL(( 
                              SELECT CAST ( 1 AS BIT ) AS 'Success', JSON_QUERY('[' + REPLACE(@c_JobIDs,'|',',') + N']') AS 'PrintJobIDs' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                           ), '')

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
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END
END -- Procedure  

GO