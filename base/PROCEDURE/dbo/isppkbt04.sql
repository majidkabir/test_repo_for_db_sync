SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispPKBT04                                                   */
/* Creation Date: 02-Dec-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-10664 - [CN] Floship Ecom Packing packlist & Courier    */
/*                     Label Printing                                   */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/*        :                                                             */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 01-MAR-2021 CSCHONG  1.1   WMS-16414 revised print logic (CS01)      */
/* 12-JUL-2021 CSCHOPNG 1.2   WMS-17456 revised print logic (CS02)      */
/* 29-OCT-2021 CSCHONG  1.3   Devops Scripts combine                    */
/* 29-OCT-2021 CSCHONG  1.4   WMS-18211 revised field logic (CS03)      */
/* 22-MAR-2021 CSCHONG  1.5   WMS-21937 add new printing (CS04)         */
/* 04-JUL-2023 WinSern  1.6   JSM-160568 @n_QueueID INT to BIGINT (ws01)*/   
/************************************************************************/
CREATE   PROCEDURE [dbo].[ispPKBT04]
   @c_printerid  NVARCHAR(50) = '',
   @c_labeltype  NVARCHAR(30) = '',
   @c_userid     NVARCHAR(256) = '',   --(CS03)
   @c_Parm01     NVARCHAR(60) = '', --Pickslipno
   @c_Parm02     NVARCHAR(60) = '', --carton from
   @c_Parm03     NVARCHAR(60) = '', --carton to
   @c_Parm04     NVARCHAR(60) = '',
   @c_Parm05     NVARCHAR(60) = '',
   @c_Parm06     NVARCHAR(60) = '',
   @c_Parm07     NVARCHAR(60) = '',
   @c_Parm08     NVARCHAR(60) = '',
   @c_Parm09     NVARCHAR(60) = '',
   @c_Parm10     NVARCHAR(60) = '',
   @c_Storerkey  NVARCHAR(15) = '',
   @c_NoOfCopy   NVARCHAR(5) = '1',
   @c_Subtype    NVARCHAR(20) = '',
   @b_Success    INT      OUTPUT,
   @n_Err        INT      OUTPUT,
   @c_ErrMsg     NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @c_Pickslipno      NVARCHAR(10)
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
         , @c_FileName        NVARCHAR( 50)
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
         , @c_Facility        NVARCHAR(5)
         , @c_Application     NVARCHAR(30)
         , @n_JobID           INT
         , @n_QueueID         BIGINT				--(ws01)
         , @n_starttcnt       INT
         , @c_JobID           NVARCHAR(10)
         , @c_PrintData       NVARCHAR(MAX)
         , @c_OrdNotes2       NVARCHAR(150)
         , @n_IsExists        INT = 0
         , @c_PDFFilePath     NVARCHAR(500) = ''
         , @c_ArchivePath     NVARCHAR(200) = ''
         , @c_defaultPrn      NVARCHAR(20) = ''
         , @c_defaultPaperprn NVARCHAR(20) = ''
         , @n_ttlcarton       NVARCHAR(150) = 1
         , @c_getstorerkey    NVARCHAR(20) = ''
         , @c_PackLFileName   NVARCHAR( 150)
         , @c_CLFileName      NVARCHAR( 150)
         , @c_PrnFileName     NVARCHAR( 150)
         , @n_counter         INT = 1
         , @n_prncopy         INT = 1                    --CS03
         , @c_PackLInvFileName  NVARCHAR( 150)           --CS04


   CREATE TABLE #TEMPPRINTJOB (
      RowId            int identity(1,1),
     PrnFilename      NVARCHAR(50)
     )


   SET @n_err = 0
   SET @b_success = 1
   SET @c_errmsg = ''
   SET @n_continue = 1
   SET @n_starttcnt = @@TRANCOUNT
   SET @c_SpoolerGroup = ''

   SET @c_Pickslipno = @c_Parm01

   SELECT TOP 1 @c_Facility = DefaultFacility
               ,@c_defaultPrn = defaultprinter
               ,@c_defaultPaperprn = defaultprinter_paper
   FROM RDT.RDTUser (NOLOCK)
   WHERE UserName = @c_userid


   SET @c_DocType = ''
   SELECT @c_OrderKey = ORDERS.OrderKey
        , @c_DocType  = ORDERS.DocType
        , @c_OrdType  = ORDERS.Type
        , @c_ExtOrderkey = ORDERS.ExternOrderKey
        , @c_Shipperkey = ORDERS.ShipperKey
        , @c_OrdNotes2 = RTRIM(ORDERS.notes2)
        , @n_ttlcarton = CASE WHEN ISNULL(ORDERS.notes,'') <> '' AND ISNUMERIC(ORDERS.notes) = 1 THEN CONVERT(int,ORDERS.notes) else 0 END
        , @c_getstorerkey = ORDERS.Storerkey
   FROM PACKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo

   IF ISNULL(@c_storerkey,'') = ''
   BEGIN
     SET @c_storerkey = @c_getstorerkey
   END

  --CS01 START

    --select @c_DocType '@c_DocType' , @n_ttlcarton '@n_ttlcarton', @c_Shipperkey  '@c_Shipperkey', @c_PrinterID '@c_PrinterID',
    --       @c_LabelType '@c_LabelType' , @c_userid '@c_userid',@c_Parm01 '@c_Parm01',@c_Parm02 '@c_Parm02',@c_Parm03 '@c_Parm03',@c_Storerkey '@c_Storerkey'
   IF @c_DocType = 'E' AND @n_ttlcarton = 1  AND @c_Shipperkey  = 'SF'
   BEGIN
      --select 'print bartender'
      EXEC isp_BT_GenBartenderCommand
                     @cPrinterID = @c_PrinterID
                  ,  @c_LabelType = @c_LabelType
                  ,  @c_userid = @c_UserId
                  ,  @c_Parm01 = @c_Parm01 --pickslipno
                  ,  @c_Parm02 = @c_Parm02 --carton from
                  ,  @c_Parm03 = @c_Parm03 --carton to
                  ,  @c_Parm04 = @c_Parm04
                  ,  @c_Parm05 = @c_Parm05
                  ,  @c_Parm06 = @c_Parm06
                  ,  @c_Parm07 = @c_Parm07
                  ,  @c_Parm08 = @c_Parm08
                  ,  @c_Parm09 = @c_Parm09
                  ,  @c_Parm10 = @c_Parm10
                  ,  @c_Storerkey = @c_Storerkey
                  ,  @c_NoCopy = @c_NoOfCopy
                  ,  @c_Returnresult = 'N'
                  ,  @n_err = @n_Err OUTPUT
                  ,  @c_errmsg = @c_ErrMsg OUTPUT

        --    select @n_err '@n_err' , @c_errmsg '@c_errmsg'

            IF @n_Err <> 0
            BEGIN
               SET @n_continue = 3
            END
       --  END

         GOTO QUIT_SP
   END
 -- CS01 END

--select @c_DocType '@c_DocType',@n_ttlcarton '@n_ttlcarton'
   ELSE
   BEGIN
     IF @c_DocType = 'E' AND @c_Shipperkey <> 'SF' -- AND @n_ttlcarton = 1  AND @c_Shipperkey  <> 'SF'     --CS03
     BEGIN

        SELECT @c_FilePath = Long,
               @c_PrintFilePath = Notes,
               @c_ReportType = Code2
     FROM dbo.CODELKUP WITH (NOLOCK)
     WHERE LISTNAME = 'PrtbyShipK'
     AND   Code = @c_ShipperKey


    IF ISNULL(@c_FilePath,'') = ''
    BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60011
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PDF Image Server Not Yet Setup/Enable In Codelkup Config. (ispPKBT04)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      GOTO QUIT_SP
   END
     /*
    SET @n_IsExists = 0
    SET @c_PDFFilePath = @c_FilePath + '\courier_' + RTRIM(@c_ExtOrderkey) + '.PDF'
    SET @c_ArchivePath = @c_FilePath + '\Archive\courier_' + RTRIM(@c_ExtOrderkey) + '.PDF'
    EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT
    IF @n_IsExists = 0
    BEGIN
       SET @c_PDFFilePath = @c_FilePath + '\Archive\courier_' + RTRIM(@c_ExtOrderkey) + '.PDF'
       SET @c_ArchivePath = ''
       EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT
    END
    */
     IF OBJECT_ID('tempdb..#DirPDFTree') IS NULL
      BEGIN
         CREATE TABLE #DirPDFTree (
           Id int identity(1,1),
           SubDirectory nvarchar(255),
           Depth smallint,
           FileFlag bit  -- 0=folder 1=file
          )

         INSERT INTO #DirPDFTree (SubDirectory, Depth, FileFlag)
         EXEC xp_dirtree_admin @c_FilePath, 2, 1    --folder, depth 0=all(default) 1..x, 0=not list file(default) 1=list file

       SELECT TOP 1 @c_CLFileName = SubDirectory
       FROM #DirPDFTree
       WHERE SubDirectory like 'courier_' + @c_ExtOrderkey + '%'     --CS01

       SELECT TOP 1 @c_PackLFileName = SubDirectory
       FROM #DirPDFTree
       WHERE SubDirectory like 'packlist_' + @c_ExtOrderkey + '%'     --CS01


       SELECT TOP 1 @c_PackLInvFileName = SubDirectory                   --CS04 S
       FROM #DirPDFTree
       WHERE SubDirectory like 'Packlist_Invoice_' + @c_ExtOrderkey + '%'     --CS04 E

          IF ISNULL(@c_CLFileName,'') = '' --OR ISNULL(@c_PackLFileName,'') = ''         --(CS02)
          BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60003
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PDF filename with externorderkey: ' + @c_ExtOrderkey + ' not found. (ispPKBT04)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END

         --CS02 START

          IF ISNULL(@c_PackLFileName,'') <> ''
          BEGIN
              INSERT INTO #TEMPPRINTJOB(PrnFilename)
              VALUES(@c_PackLFileName)
          END

         --CS02 END

        --CS04 START

          IF ISNULL(@c_PackLInvFileName,'') <> ''
          BEGIN
              INSERT INTO #TEMPPRINTJOB(PrnFilename)
              VALUES(@c_PackLInvFileName)
          END

         --CS04 END
         INSERT INTO #TEMPPRINTJOB(PrnFilename)
         VALUES(@c_CLFileName)

    DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
    SELECT DISTINCT PrnFilename
    FROM   #TEMPPRINTJOB

    OPEN CUR_RESULT

    FETCH NEXT FROM CUR_RESULT INTO @c_PrnFileName

    WHILE @@FETCH_STATUS <> -1
    BEGIN

    IF @c_PrnFileName like 'courier_%'
    BEGIN
       SET @n_prncopy = CASE WHEN @n_ttlcarton <> 0 THEN @n_ttlcarton ELSE 1 END     --CS03

       IF @c_OrdNotes2 = '4x6'
       BEGIN
       SELECT @c_WinPrinter = WinPrinter
             ,@c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup),'')
        FROM rdt.rdtPrinter WITH (NOLOCK)
        WHERE PrinterID =  @c_defaultPrn
       END
        ELSE
       --IF @c_OrdNotes2='A4'
       BEGIN
        SELECT @c_WinPrinter = WinPrinter
               ,@c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup),'')
         FROM rdt.rdtPrinter WITH (NOLOCK)
         WHERE PrinterID =  @c_defaultPaperprn
        END
    END
    ELSE
    BEGIN

    SET @n_prncopy = 1    --CS03

    SELECT @c_WinPrinter = WinPrinter
          ,@c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup),'')
      FROM rdt.rdtPrinter WITH (NOLOCK)
      WHERE PrinterID =  @c_defaultPaperprn
   END

      IF CHARINDEX(',' , @c_WinPrinter) > 0
      BEGIN
         SET @c_PrinterName = LEFT( @c_WinPrinter , (CHARINDEX(',' , @c_WinPrinter) - 1) )
      END
      ELSE
      BEGIN
         SET @c_PrinterName =  @c_WinPrinter
      END

      SET @c_PrintCommand = '"' + @c_PrintFilePath + '" /t "' + @c_FilePath + '\' + @c_PrnFileName + '" "' + @c_PrinterName + '"'


       SET @c_JobStatus = '9'
       SET @c_PrintJobName = 'PRINT_' + @c_ReportType
       SET @c_TargetDB = DB_NAME()

      IF @c_SpoolerGroup = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63545
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Spooler Group Not Setup for printerid: '
                           + RTRIM(@c_defaultPrn) + ' Or Printerid :' + RTRIM(@c_defaultPaperprn) +' (ispPKBT04)'
         GOTO QUIT_SP
      END

       SELECT
            @c_IPAddress = IPAddress
         ,  @c_PortNo = PortNo
         ,  @c_Command = Command
         ,  @c_IniFilePath = IniFilePath
      FROM rdt.rdtSpooler WITH (NOLOCK)
      WHERE SpoolerGroup = @c_SpoolerGroup

   BEGIN TRAN

   IF NOT EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE UserName = @c_UserId)
   BEGIN
      SELECT @n_Mobile = ISNULL(MAX(Mobile),0) + 1
      FROM RDT.RDTMOBREC (NOLOCK)

      INSERT INTO RDT.RDTMOBREC (Mobile, UserName, Storerkey, Facility, Printer, ErrMsg, Inputkey)
      VALUES (@n_Mobile, @c_UserId, @c_Storerkey, ISNULL(@c_Facility,''), ISNULL(@c_PrinterID,''),'WMS',0)

      IF @@ERROR <> 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 63520
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTMOBREC (ispPKBT04)'
         GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
        SELECT TOP 1 @n_Mobile = Mobile
        FROM RDT.RDTMOBREC (NOLOCK)
        WHERE UserName = @c_UserId

        UPDATE RDT.RDTMOBREC WITH (ROWLOCK)
        SET Storerkey = @c_Storerkey,
            Facility = ISNULL(@c_Facility,''),
            Printer = ISNULL(@c_PrinterID,'')
        WHERE Mobile = @n_Mobile

      IF @@ERROR <> 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 63530
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Error On Table RDT.RDTMOBREC (ispPKBT04)'
         GOTO QUIT_SP
      END
   END

--CS03 START
WHILE @n_prncopy >= 1
BEGIN
         INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms
                              , Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10
                              , Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, Storerkey, Function_ID)
   VALUES(@c_PrintJobName, @c_ReportType, @c_JobStatus, '', '1'
         ,@c_Parm01, @c_Parm02, @c_Parm03, @c_Parm04, @c_Parm05, @c_Parm06, @c_Parm07, @c_Parm08, @c_Parm09, @c_Parm10
        -- ,'', '', '', '', '', '', '', '', '', ''
         ,@c_PrinterID,@n_prncopy, @n_Mobile, @c_TargetDB                          --CS03
        , @c_PrintCommand, 'QCOMMANDER', @c_Storerkey, '999')

   SET @n_JobID = SCOPE_IDENTITY()
   SET @c_JobID       = CAST( @n_JobID AS NVARCHAR( 10))


   IF @@ERROR <> 0
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 63540
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTPrintJob (ispPKBT04)'
      GOTO QUIT_SP
   END

   SET @c_Application = 'QCOMMANDER'

      IF @c_Application = 'QCOMMANDER'
      BEGIN
         SET @c_Command = @c_Command + ' ' + @c_JobID

         INSERT INTO TCPSocket_QueueTask (CmdType, Cmd, StorerKey, Port, TargetDB, IP, TransmitLogKey,datastream)
         VALUES ('CMD', @c_PrintCommand, @c_StorerKey, @c_PortNo, DB_NAME(), @c_IPAddress, @c_JobID,@c_Application )

         SET @n_QueueID = SCOPE_IDENTITY()

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63550
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error QCommander Task (ispPKBT04)'
            GOTO QUIT_SP
         END

         SET @c_PrintData =
            '<STX>' +
               'CMD|' +
               CAST( @n_QueueID AS NVARCHAR( 20)) + '|' +
               DB_NAME() + '|' +
               @c_PrintCommand +
            '<ETX>'
      END

      EXEC isp_QCmd_SendTCPSocketMsg
            @cApplication  = 'QCOMMANDER'
         ,  @cStorerKey    = @c_StorerKey
         ,  @cMessageNum   = @c_JobID
         ,  @cData         = @c_PrintData
         ,  @cIP           = @c_IPAddress
         ,  @cPORT         = @c_PortNo
         ,  @cIniFilePath  = @c_IniFilePath
         ,  @cDataReceived = @c_DataReceived OUTPUT
         ,  @bSuccess      = @b_Success      OUTPUT
         ,  @nErr          = @n_err          OUTPUT
         ,  @cErrMsg       = @c_ErrMsg       OUTPUT


      IF @n_err <> 0
      BEGIN
         GOTO QUIT_SP
      END

     SET @n_prncopy= @n_prncopy - 1

END --CS03 END
      --QCMD_END:

    --END

     FETCH NEXT FROM CUR_RESULT INTO @c_PrnFileName
     END

    END
  END
 END
   SET @b_success = 2

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispPKBT04"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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


GRANT EXECUTE ON ispPKBT04 TO NSQL

GO