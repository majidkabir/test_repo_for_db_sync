SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispGetUCCLABELPDF02                                         */
/* Creation Date: 18-Mar-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-12441 - MY_JDSPORTS_DHL_ECOM_packing_PrintShipLabel_PDF */
/*          WMS-13010 - MY - JDSPORTS - SingPost Print Ship Label PDF   */
/*                                                                      */
/* Called By: isp_GetPrint2PDFConfig                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGetUCCLABELPDF02]
       @c_Storerkey     NVARCHAR(15),
       @c_Facility      NVARCHAR(5), 
       @c_Configkey     NVARCHAR(30),
       @c_Param01       NVARCHAR(50),
       @c_Param02       NVARCHAR(50),
       @c_Param03       NVARCHAR(50),
       @c_Param04       NVARCHAR(50),
       @c_Param05       NVARCHAR(50),
       @c_PdfFolder     NVARCHAR(500),
       @c_PdfFile       NVARCHAR(500) OUTPUT,
       @c_Printer       NVARCHAR(500) OUTPUT,
       @c_ArchiveFolder NVARCHAR(500) OUTPUT,
       @c_ActionType    NVARCHAR(10)  OUTPUT,  --2 = Print and don't move 3 = Print and move (Default)
       @n_PrintAction   INT           OUTPUT,  --0=Not print PDF  1=Print PDF   2=Print PDF and continue other printing
       @c_Dimension     NVARCHAR(50)  OUTPUT,  --Dimension in mm x mm, eg. 210x297
       @n_NoOfPDFSheet  INT = 1,               --PDF Sheets number (For 1 ReportType print multiple layout)
       --@c_PostPrinting  NVARCHAR(1)   OUTPUT,  --Y - PostPrinting, N - DirectPrint (Need to wait)
       @b_Success       INT           OUTPUT,  
       @n_Err           INT           OUTPUT, 
       @c_ErrMsg        NVARCHAR(255) OUTPUT
   
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_continue        INT 
         , @c_Orderkey        NVARCHAR(10)
         , @c_OrdType         NVARCHAR(30)
         , @c_DocType         NVARCHAR(10)
         , @c_ExtOrderkey     NVARCHAR(10)
         , @c_Shipperkey      NVARCHAR(15)

   DECLARE @c_ReportType      NVARCHAR( 10)
         , @c_ProcessType     NVARCHAR( 15)
         , @c_FilePath        NVARCHAR(100)       
         , @c_PrintFilePath   NVARCHAR(100)      
         , @c_PrintCommand    NVARCHAR(MAX)    
         , @c_WinPrinter      NVARCHAR(128)  
         , @c_PrinterName     NVARCHAR(100) 
         , @c_FileName        NVARCHAR(255)     
         , @c_JobStatus       NVARCHAR( 1)    
         , @c_PrintJobName    NVARCHAR(50)
         , @c_TargetDB        NVARCHAR(20)
         , @n_Mobile          INT   
         , @c_SpoolerGroup    NVARCHAR(20)
         , @c_IPAddress       NVARCHAR(40)               
         , @c_PortNo          NVARCHAR(5)           
         , @c_Command         NVARCHAR(1024)            
         , @c_IniFilePath     NVARCHAR(200)  
         , @c_DataReceived    NVARCHAR(4000) 
         , @c_Application     NVARCHAR(30)           
         , @n_JobID           INT    
         , @n_QueueID         INT 
         , @n_starttcnt       INT
         , @c_JobID           NVARCHAR(10) 
         , @c_PrintData       NVARCHAR(MAX) 
         , @c_userid          NVARCHAR(20) 
         , @c_PrinterID       NVARCHAR(20)    
         , @n_IsExists        INT = 0  
         , @c_PDFFilePath     NVARCHAR(500) = ''
         , @c_ArchivePath     NVARCHAR(200) = ''
         , @c_TrackingNo      NVARCHAR(30)  = ''
         , @c_Type            NVARCHAR(20)  = ''
         , @c_Option3         NVARCHAR(50) = ''
          
   --CREATE TABLE #DirPDFTree (
   --   ID INT IDENTITY(1,1),
   --   SubDirectory NVARCHAR(255),
   --   Depth SMALLINT,
   --   FileFlag BIT  -- 0=folder 1=file
   --)
                                            
   SET @n_err = 0
   SET @b_success = 1
   SET @c_errmsg = ''
   SET @n_continue = 1
   SET @n_starttcnt = @@TRANCOUNT
   SET @c_SpoolerGroup = '' 
   SET @c_userid = SUSER_SNAME()

   SELECT @c_OrderKey    = ORDERS.OrderKey 
        , @c_DocType     = ORDERS.DocType 
        , @c_OrdType     = ORDERS.Type
        , @c_ExtOrderkey = ORDERS.ExternOrderKey
        , @c_Shipperkey  = LTRIM(RTRIM(ISNULL(ORDERS.ShipperKey,'')))
        , @c_TrackingNo  = LTRIM(RTRIM(ISNULL(ORDERS.TrackingNo,'')))
   FROM PACKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
   WHERE PACKHEADER.PickSlipNo = @c_Param01 

   SELECT @c_Option3 = ISNULL(SC.Option3,'')
   FROM STORERCONFIG SC (NOLOCK)
   WHERE SC.Storerkey = @c_Storerkey
   AND SC.Configkey = @c_Configkey

   CREATE TABLE #TEMP_Shipperkey (Shipperkey NVARCHAR(15))

   INSERT INTO #TEMP_Shipperkey
   SELECT LTRIM(RTRIM(ColValue)) FROM dbo.fnc_delimsplit (',',@c_Option3) 

   --IF LTRIM(RTRIM(ISNULL(@c_Type,''))) <> 'IOT'
   --IF LTRIM(RTRIM(ISNULL(@c_Type,''))) <> 'E'

   IF LTRIM(RTRIM(ISNULL(@c_TrackingNo,''))) = ''
   BEGIN
      SET @n_PrintAction = 0
      GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM #TEMP_Shipperkey WHERE Shipperkey = @c_Shipperkey)
   BEGIN
      SET @n_PrintAction = 0
      GOTO QUIT_SP
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      IF ISNULL(@c_Printer,'') = ''
      BEGIN
         SELECT TOP 1 
            @c_PrinterID = DefaultPrinter
         FROM RDT.RDTUser (NOLOCK)   
         WHERE UserName = @c_userid
      END
      ELSE
      BEGIN
         IF EXISTS (SELECT 1 FROM RDT.RDTPRINTER (NOLOCK) WHERE PRINTERID = @c_Printer)
         BEGIN
            SET @c_PrinterID = @c_Printer
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60010  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) 
                  + ': PrinterID not setup. (' + @c_Printer + ')' 
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            SET @n_PrintAction = 0
            GOTO QUIT_SP
         END
      END
   END

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      IF ISNULL(@c_PdfFolder,'') = '' 
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60011   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) 
               + ': PDF Image Server Not Yet Setup/Enable In Storerconfig for Configkey :' + @c_Configkey + ' (ispGetUCCLABELPDF02) '
               + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
       END

      IF ISNULL(@c_ArchiveFolder,'') = ''
      BEGIN
         SET @c_ArchiveFolder = @c_PdfFolder + '\Archive'  
      END

      IF RIGHT(RTRIM(@c_PdfFolder),1) <> '\'
      BEGIN
         SET @c_PdfFolder = @c_PdfFolder + '\'
      END

      IF RIGHT(RTRIM(@c_ArchiveFolder),1) <> '\'
      BEGIN
         SET @c_ArchiveFolder = @c_ArchiveFolder + '\'
      END

      --Normal Folder
      SET @n_IsExists = 0

      SET @c_PDFFilePath = @c_PdfFolder  + 'JDSPORTS_' + @c_Shipperkey + '_SHPLBL_' + RTRIM(@c_TrackingNo) + '.PDF'
      SET @c_PdfFile = @c_PDFFilePath
      EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT

      IF @n_IsExists = 0
      BEGIN
         SET @c_PDFFilePath = @c_ArchiveFolder + 'JDSPORTS_' + @c_Shipperkey + '_SHPLBL_' + RTRIM(@c_TrackingNo) + '.PDF'
         SET @c_PdfFile = @c_PDFFilePath
         SET @c_ArchivePath = '' 
         SET @c_ActionType = '2'
         EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT 
      END
    
      IF @n_IsExists = 0 
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60003   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PDF filename with TrackingNo: ' + @c_TrackingNo + ' not found. '
                         +'(ispGetUCCLABELPDF02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP  
      END
   END
   
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT @c_WinPrinter = WinPrinter  
            ,@c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup),'') 
      FROM rdt.rdtPrinter WITH (NOLOCK)  
      WHERE PrinterID =  @c_PrinterID 
   
      IF CHARINDEX(',' , @c_WinPrinter) > 0 
      BEGIN
         SET @c_Printer = LEFT( @c_WinPrinter , (CHARINDEX(',' , @c_WinPrinter) - 1) )    
         SET @c_PrinterName = LEFT( @c_WinPrinter , (CHARINDEX(',' , @c_WinPrinter) - 1) )    
      END
      ELSE
      BEGIN
         SET @c_Printer = @c_WinPrinter
         SET @c_PrinterName =  @c_WinPrinter 
      END
   END

   IF ISNULL(@c_PDFFilePath,'') = ''
   BEGIN
      SET @n_PrintAction = 0
   END
   ELSE
   BEGIN
      SET @n_PrintAction = 2
   END
           
  --QCMD_END:                  
  --SET @b_success = 2         
                
  QUIT_SP:

   --IF OBJECT_ID('tempdb..#DirPDFTree') IS NOT NULL
   --   DROP TABLE #DirPDFTree

  IF @n_continue=3  -- Error Occured - Process And Return
  BEGIN
      SELECT @b_success = 0     
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
      BEGIN
         ROLLBACK TRAN
      END
      ELSE 
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt 
         BEGIN
            COMMIT TRAN
         END          
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispGetUCCLABELPDF02"
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE 
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt 
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END  

SET QUOTED_IDENTIFIER OFF 

GO