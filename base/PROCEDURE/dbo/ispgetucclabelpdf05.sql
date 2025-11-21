SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispGetUCCLABELPDF05                                         */
/* Creation Date: 10-Jun-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17206 - RG - aCommerce Adidas - EXCEED Packing UCCLabel */
/*                                                                      */
/* Called By: isp_GetPrint2PDFConfig                                    */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 22-Apr-2022 WLChooi  1.1   DevOps Combine Script                     */
/* 22-Apr-2022 WLChooi  1.1   WMS-19490 Cater of OrderGroup aCommerce   */
/*                            for SG (WL01)                             */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispGetUCCLABELPDF05]
       @c_Storerkey       NVARCHAR(15),
       @c_Facility        NVARCHAR(5), 
       @c_Configkey       NVARCHAR(30),
       @c_Param01         NVARCHAR(50),
       @c_Param02         NVARCHAR(50),
       @c_Param03         NVARCHAR(50),
       @c_Param04         NVARCHAR(50),
       @c_Param05         NVARCHAR(50),
       @c_PdfFolder       NVARCHAR(500),
       @c_PdfFile         NVARCHAR(500)   OUTPUT,
       @c_Printer         NVARCHAR(500)   OUTPUT,
       @c_ArchiveFolder   NVARCHAR(500)   OUTPUT,
       @c_ActionType      NVARCHAR(10)    OUTPUT,  --2 = Print and don't move 3 = Print and move (Default)
       @n_PrintAction     INT             OUTPUT,  --0=Not print PDF  1=Print PDF   2=Print PDF and continue other printing
       @c_Dimension       NVARCHAR(50)    OUTPUT,  --Dimension in mm x mm, eg. 210x297
       @n_NoOfPDFSheet    INT = 1,                 --PDF Sheets number (For 1 ReportType print multiple layout)
       @c_FromModule      NVARCHAR(100),           --Call from which module from Exceed
       @c_PrinterType     NVARCHAR(100),           --PrinterType: LABEL / PAPER, Default Label
       @c_SearchMethod    NVARCHAR(10),            --1 = Get the PDF with complete file name 2 = Search the folder with partial PDF name
       --@c_PostPrinting  NVARCHAR(1)   OUTPUT,  --Y - PostPrinting, N - DirectPrint (Need to wait)
       @b_Success         INT             OUTPUT,  
       @n_Err             INT             OUTPUT, 
       @c_ErrMsg          NVARCHAR(255)   OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_continue        INT 

   DECLARE @c_PdfName         NVARCHAR(MAX)    
         , @c_WinPrinter      NVARCHAR(128)  
         , @c_PrinterName     NVARCHAR(100) 
         , @c_SpoolerGroup    NVARCHAR(20)
         , @n_starttcnt       INT
         , @c_userid          NVARCHAR(20) 
         , @c_PrinterID       NVARCHAR(20)    
         , @n_IsExists        INT = 0  
         , @c_PDFFilePath     NVARCHAR(500) = ''
         , @c_ArchivePath     NVARCHAR(200) = ''
         , @c_TrackingNo      NVARCHAR(30)  = ''
         , @c_Type            NVARCHAR(20)  = ''
         , @c_Option5         NVARCHAR(4000) = ''
         , @c_Shipperkey      NVARCHAR(50) = ''
         , @c_GetPdfName      NVARCHAR(MAX) 
         , @b_Debug           INT = 0
         , @c_OrderGroup      NVARCHAR(50)   --WL01
         , @c_Country         NVARCHAR(10)   --WL01
   	    
   SET @n_err = 0
   SET @b_success = 1
   SET @c_errmsg = ''
   SET @n_continue = 1
   SET @n_starttcnt = @@TRANCOUNT
   SET @c_SpoolerGroup = '' 
   SET @c_userid = SUSER_SNAME()

   --WL01 S
   SELECT @c_OrderGroup = OH.OrderGroup
   FROM PACKHEADER PH (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = PH.Orderkey
   WHERE PH.Pickslipno = @c_Param01

   SELECT @c_Country = N.NSQLValue
   FROM NSQLCONFIG N (NOLOCK)
   WHERE N.ConfigKey = 'Country'
   --WL01 E

   IF @c_FromModule = 'PACKING_AUTO' 
   AND (@c_OrderGroup = 'aCommerce' AND @c_Country = 'SG')   --WL01
   BEGIN
      SET @c_PDFFilePath = ''
      GOTO SKIP_PRINT
   END

   --WL01 S
   IF @c_OrderGroup = 'aCommerce' AND @c_Storerkey = 'ADIDAS' AND @c_Country = 'SG'
   BEGIN
      --For SG
      EXEC [dbo].[isp_GetPrint2PDFConfig] 
           @c_Storerkey     = 'ACOMM-ADI'
         , @c_Facility      = @c_facility
         , @c_Configkey     = @c_Configkey    
         , @c_Param01       = @c_Param01      
         , @c_Param02       = @c_Param02      
         , @c_Param03       = @c_Param03      
         , @c_Param04       = @c_Param04      
         , @c_Param05       = @c_Param05      
         , @c_PdfFile       = @c_PdfFile        OUTPUT
         , @c_Printer       = @c_Printer        OUTPUT
         , @c_ArchiveFolder = @c_ArchiveFolder  OUTPUT
         , @c_ActionType    = @c_ActionType     OUTPUT
         , @n_PrintAction   = @n_PrintAction    OUTPUT
         , @c_Dimension     = @c_Dimension      OUTPUT
         , @n_NoOfPDFSheet  = @n_NoOfPDFSheet
         , @b_Success       = @b_Success        OUTPUT
         , @n_Err           = @n_Err            OUTPUT
         , @c_ErrMsg        = @c_ErrMsg         OUTPUT
         , @c_FromModule    = @c_FromModule

      GOTO QUIT_SP
   END
   --WL01 E

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      IF ISNULL(@c_Printer,'') = ''
      BEGIN
         SELECT TOP 1 
            @c_PrinterID = CASE WHEN @c_PrinterType = 'PAPER' THEN DefaultPrinter_Paper ELSE DefaultPrinter END
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
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60040  
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
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60050  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) 
               + ': PDF Image Server Not Yet Setup/Enable In Storerconfig for Configkey :' + @c_Configkey + ' (ispGetUCCLABELPDF05) '
               + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         SET @n_PrintAction = 0
         GOTO QUIT_SP
       END

      IF RIGHT(RTRIM(@c_PdfFolder),1) <> '\'
      BEGIN
         SET @c_PdfFolder = @c_PdfFolder + '\'
      END

      IF ISNULL(@c_ArchiveFolder,'') = ''
      BEGIN
         SET @c_ArchiveFolder = 'Archive'
      END
      
      IF RIGHT(LTRIM(RTRIM(@c_ArchiveFolder)),1) <> '\'
      BEGIN
         SET @c_ArchiveFolder = @c_ArchiveFolder + '\'
      END

      IF LEFT(LTRIM(@c_ArchiveFolder),2) <> '\\'
      BEGIN
         SET @c_ArchiveFolder = @c_PdfFolder + @c_ArchiveFolder
      END

      SET @c_PdfName = @c_PdfFile

      --SELECT @c_SearchMethod, @c_PdfFile
      --Method 1 - Get the PDF with complete file name, eg. INVOICE_LZD_20210106001_20200301.PDF
      IF (@n_continue = 1 OR @n_continue = 2) AND @c_SearchMethod = '1'
      BEGIN
         --Normal Folder
         SET @n_IsExists = 0
         SET @c_PDFFilePath = @c_PdfFolder + @c_PdfName
         SET @c_PdfFile = @c_PDFFilePath
         EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT
         
         IF @n_IsExists = 0
         BEGIN
            SET @c_PDFFilePath = @c_ArchiveFolder + @c_PdfName
            SET @c_PdfFile = @c_PDFFilePath
            SET @c_ArchivePath = '' 
            SET @c_ActionType = '2'
            EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT 
         END
         
         IF @n_IsExists = 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60060   
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PDF - ' + @c_PdfFile + ' Not Found.'
                            +'(ispGetUCCLABELPDF05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            SET @n_PrintAction = 0
            GOTO QUIT_SP  
         END
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

 SKIP_PRINT:
   IF ISNULL(@c_PDFFilePath,'') = ''
   BEGIN
      SET @n_PrintAction = 0
   END
   ELSE
   BEGIN
   	SET @n_PrintAction = 1
   END
  
QUIT_SP:
   IF OBJECT_ID('tempdb..#DirPDFTree') IS NOT NULL
      DROP TABLE #DirPDFTree
      
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispGetUCCLABELPDF05"
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