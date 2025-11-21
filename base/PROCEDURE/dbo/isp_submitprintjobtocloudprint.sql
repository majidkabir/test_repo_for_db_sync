SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_SubmitPrintJobToCloudPrint                      */  
/* Creation Date: 2023-03-29                                             */  
/* Copyright: Maersk                                                     */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: WMS-22125 - Backend Bartender DB-MQ                          */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date       Author   Ver   Purposes                                    */ 
/* 2023-03-29 Wan      1.0   Created & DevOps Combine Script             */
/* 2024-05-24 CSCHONG  1.1   WMS-25490 revised field logic (CS01)        */ 
/* 2024-12-10 YeeKung  1.2   FCR-1787 Add CMDSUMATRA (yeekung01)         */
/*************************************************************************/   
CREATE   PROCEDURE [dbo].[isp_SubmitPrintJobToCloudPrint] 
   @c_DataProcess    NVARCHAR(50) = ''
,  @c_Storerkey      NVARCHAR(15) = ''   
,  @c_PrintType      NVARCHAR(30) = ''
,  @c_PrinterName    NVARCHAR(128)= ''
,  @c_IP             NVARCHAR(40) = ''
,  @c_Port           NVARCHAR(5)  = ''
,  @c_DocumentType   NVARCHAR(20) = ''
,  @c_DocumentId     NVARCHAR(20) = ''
,  @c_JobID          NVARCHAR(20) = ''
,  @c_Data           NVARCHAR(MAX)= ''
,  @b_Success        INT          = 1  OUTPUT  
,  @n_Err            INT          = 0  OUTPUT  
,  @c_ErrMsg         NVARCHAR(255)= '' OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
           @n_StartTCnt             INT            = @@TRANCOUNT
         , @n_Continue              INT            = 1
         , @n_POS                   INT            = 0
         
         , @n_WebRequestTimeout     INT            = 120000
         , @n_WebServiceActiveFlag  INT            = 0
         
         , @n_NoOfCopy              INT            = 1
         , @c_ClientID              NVARCHAR(50)   = ''   
         , @c_CloudClientPrinterID  NVARCHAR(30)   = ''
         
         , @c_PrintClientID         NVARCHAR(50)   = ''
         , @c_CmdType               NVARCHAR(10)   = ''
         , @c_PaperSizeWxH          NVARCHAR(15)   = 'A4'
         , @c_DCropWidth            NVARCHAR(10)   = '0'
         , @c_DCropHeight           NVARCHAR(10)   = '0'
         , @c_IsLandScape           NVARCHAR(1)    = '0'
         , @c_IsColor               NVARCHAR(1)    = '0'
         , @c_IsDuplex              NVARCHAR(1)    = '0'
         , @c_IsCollate             NVARCHAR(1)    = '0' 
         , @c_MoveToArchive         NVARCHAR(1)    = '0' 
         
         , @c_Encrypted             NVARCHAR(50)   = ''  

         , @c_B64FileSrc            NVARCHAR(1024) = ''
         
         , @c_Data_Base64           NVARCHAR(MAX)  = '' 
         , @c_RequestString         NVARCHAR(MAX)  = '' 
         , @c_ResponseString        NVARCHAR(MAX)  = ''  
         , @c_IniFilePath           NVARCHAR(225)  = ''   
         , @c_WebRequestURL         NVARCHAR(250)  = ''  
         , @c_WebRequestMethod      NVARCHAR(10)   = 'POST'  
         , @c_WebRequestContentType NVARCHAR(100)  = 'application/json'  
         , @c_WebRequestEncoding    NVARCHAR(30)   = 'UTF-8'  
         , @c_vbErrMsg              NVARCHAR(MAX)  = ''   
         , @c_vbHttpStatusCode      NVARCHAR(20)   = ''   
         , @c_vbHttpStatusDesc      NVARCHAR(1000) = '' 
         
         --, @n_SerialNo              INT            = 0
         , @c_ReqeustID             NVARCHAR(20)   = ''  
         , @c_Version               NVARCHAR(10)   = ''
         , @c_Status                NVARCHAR(10)   = ''
         , @c_PrefixPrn             NVARCHAR(100)  = '\\localhost\'         --CS01
         
   DECLARE @t_JFormat   TABLE
         ( RowID        INT            IDENTITY(1,1)  PRIMARY KEY
         , ReqeustID    NVARCHAR(30)   NOT NULL DEFAULT('')
         , [Type]       NVARCHAR(30)   NOT NULL DEFAULT('')  
         , ClientID     NVARCHAR(50)   NOT NULL DEFAULT('') 
         , [Version]    NVARCHAR(10)   NOT NULL DEFAULT('')                   
         , PrinterName  NVARCHAR(128)  NOT NULL DEFAULT('')
         , PrinterIP    NVARCHAR(40)   NOT NULL DEFAULT('')
         , PrinterPort  NVARCHAR(5)    NOT NULL DEFAULT('')
         , TaskID       NVARCHAR(256)  NOT NULL DEFAULT('')
         , Preview      NVARCHAR(30)   NOT NULL DEFAULT('')
         , DocumentId   NVARCHAR(20)   NOT NULL DEFAULT('')
         , [Data]       NVARCHAR(MAX)  NOT NULL DEFAULT('')
         , DocumentType NVARCHAR(20)   NOT NULL DEFAULT('')
         ) 
          
   SET @b_Success = 1   
   SET @n_Err     = 0   
   SET @c_ErrMsg  = ''  

   SELECT @c_CloudClientPrinterID = IIF(rpjl.CloudClientPrinterID <> '', rpjl.CloudClientPrinterID, rpjl.Printer)
         ,@c_PaperSizeWxH         = rpjl.PaperSizeWxH
         ,@c_DCropWidth           = rpjl.DCropWidth  
         ,@c_DCropHeight          = rpjl.DCropHeight 
         ,@c_IsLandScape          = rpjl.IsLandScape 
         ,@c_IsColor              = rpjl.IsColor     
         ,@c_IsDuplex             = rpjl.IsDuplex  
         ,@c_IsCollate            = rpjl.IsCollate 
         ,@n_NoOfCopy             = rpjl.NoofCopy --(yeekung)
   FROM rdt.RDTPrintJob_Log AS rpjl (NOLOCK)
   WHERE rpjl.JobId = @c_JobID
   
   IF @c_CloudClientPrinterID = ''
   BEGIN
      SELECT @c_CloudClientPrinterID = IIF(rpj.CloudClientPrinterID <> '', rpj.CloudClientPrinterID, rpj.Printer)
            ,@c_PaperSizeWxH         = rpj.PaperSizeWxH
            ,@c_DCropWidth           = rpj.DCropWidth  
            ,@c_DCropHeight          = rpj.DCropHeight 
            ,@c_IsLandScape          = rpj.IsLandScape 
            ,@c_IsColor              = rpj.IsColor     
            ,@c_IsDuplex             = rpj.IsDuplex   
            ,@c_IsCollate            = rpj.IsCollate                     
      FROM rdt.RDTPrintJob AS rpj(NOLOCK)
      WHERE rpj.JobId = @c_JobID
   END
   
   SELECT @c_PrintClientID = rp.CloudPrintClientID
   FROM rdt.RDTPrinter AS rp WITH (NOLOCK)
   LEFT OUTER JOIN dbo.CloudPrintConfig AS cpc WITH (NOLOCK) ON cpc.PrintClientID = rp.CloudPrintClientID 
   WHERE rp.PrinterID = @c_CloudClientPrinterID 
   
   IF @c_PrintClientID = ''
   BEGIN
      GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.CloudPrintConfig AS cpc WITH (NOLOCK) 
                  WHERE cpc.PrintClientID = @c_PrintClientID 
                  )
   BEGIN
      GOTO QUIT_SP
   END
   
   SET @c_MoveToArchive = '0'
   IF CHARINDEX('<MoveToArchive>',@c_Data,1) > 0
   BEGIN
      SET @c_MoveToArchive = '1'
      SET @c_Data = REPLACE(@c_Data, '<MoveToArchive>','')
   END

   IF @c_Data = ''
   BEGIN
      GOTO QUIT_SP
   END

   --CS01 S
   IF UPPER(@c_PrintType) = 'ZPL'
   BEGIN
     SET @c_PrinterName = @c_PrefixPrn + @c_PrinterName
   END

   --CS01 E
   
   BEGIN TRY
      SET @c_vbErrMsg = '' 
      EXEC MASTER.[dbo].[isp_Base64Encode]  
         @c_StringEncoding = 'UTF-8'   
      ,  @c_InputString    = @c_Data  
      ,  @c_OutputString   = @c_Data_Base64  OUTPUT     
      ,  @c_vbErrMsg       = @c_vbErrMsg     OUTPUT 
   END TRY
   BEGIN CATCH
      SET @n_Err      = ERROR_NUMBER() 
      SET @c_vbErrMsg = CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + ' - ' + ERROR_MESSAGE() 
   END CATCH 
      
   IF @c_vbErrMsg <> ''
   BEGIN
      SET @n_Continue = 3  
      SET @n_Err      = 89010  
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ':'  
                      + 'Error Executing [isp_Base64Encode]. (isp_SubmitPrintJobToCloudPrint)'  
                      + ' (' + @c_vbErrMsg + ')'   
      GOTO QUIT_SP  
   END 

   SET @c_CmdType    = UPPER(IIF(@c_PrintType NOT IN ('BARTENDER','ZPL','CMDSUMATRA'), 'PDF', @c_PrintType))

   SET @c_B64FileSrc = IIF(@c_CmdType  IN ('PDF','CMDSUMATRA'), @c_Data_Base64, '')
      
   IF @c_B64FileSrc <> ''
   BEGIN
      SET @c_Data_Base64= ''
   END
   
   IF @c_PaperSizeWxH = '' SET @c_PaperSizeWxH = 'A4'
   
   INSERT INTO dbo.CloudPrintTask
         (
             PrintClientID
         ,   CmdType
         ,   B64Command
         ,   B64FileSrc
         ,   [IP]
         ,   [Port]
         ,   PrinterName
         ,   RefDocType        
         ,   RefDocID
         ,   RefJobID
         ,   PaperSizeWxH
         ,   DCropWidth
         ,   DCropHeight 
         ,   IsLandScape 
         ,   IsColor    
         ,   IsDuplex
         ,   IsCollate                                            
         ,   PrintCopy
         ,   MoveToArchive
         )
   VALUES
         (
             @c_PrintClientID
         ,   @c_CmdType    
         ,   @c_Data_Base64 
         ,   @c_B64FileSrc 
         ,   @c_IP
         ,   @c_Port            
         ,   @c_PrinterName
         ,   @c_DocumentType        
         ,   @c_DocumentId
         ,   @c_JobID
         ,   @c_PaperSizeWxH
         ,   @c_DCropWidth
         ,   @c_DCropHeight 
         ,   @c_IsLandScape 
         ,   @c_IsColor    
         ,   @c_IsDuplex 
         ,   @c_IsCollate 
         ,   @n_NoOfCopy            
         ,   @c_MoveToArchive
         )
   
   QUIT_SP:  
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, '[isp_SubmitPrintJobToCloudPrint]'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO