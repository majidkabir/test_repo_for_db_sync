SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispPKBT12                                                   */
/* Creation Date: 06-Dec-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-21279 - [CN] PVHSZ ECOM Packing Printing _CR            */
/*                                                                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/*        :                                                             */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 06-DEC-2022 CSCHONG  1.3   Devops Scripts combine                    */
/* 10-Apr-2023 WLChooi  1.1   WMS-22255 - Filter by Shipperkey (WL01)   */
/* 04-JUL-2023 WinSern  1.2   JSM-160585 @n_QueueID INT to BIGINT (ws01)*/
/************************************************************************/
CREATE   PROCEDURE [dbo].[ispPKBT12]
   @c_printerid NVARCHAR(50)  = ''
 , @c_labeltype NVARCHAR(30)  = ''
 , @c_userid    NVARCHAR(256) = '' --(CS03)
 , @c_Parm01    NVARCHAR(60)  = '' --Pickslipno
 , @c_Parm02    NVARCHAR(60)  = '' --carton from
 , @c_Parm03    NVARCHAR(60)  = '' --carton to
 , @c_Parm04    NVARCHAR(60)  = ''
 , @c_Parm05    NVARCHAR(60)  = ''
 , @c_Parm06    NVARCHAR(60)  = ''
 , @c_Parm07    NVARCHAR(60)  = ''
 , @c_Parm08    NVARCHAR(60)  = ''
 , @c_Parm09    NVARCHAR(60)  = ''
 , @c_Parm10    NVARCHAR(60)  = ''
 , @c_Storerkey NVARCHAR(15)  = ''
 , @c_NoOfCopy  NVARCHAR(5)   = '1'
 , @c_Subtype   NVARCHAR(20)  = ''
 , @b_Success   INT           OUTPUT
 , @n_Err       INT           OUTPUT
 , @c_ErrMsg    NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue     INT
         , @c_Pickslipno   NVARCHAR(10)
         , @c_Orderkey     NVARCHAR(10)
         , @c_OrdType      NVARCHAR(30)
         , @c_DocType      NVARCHAR(10)
         , @c_ExtOrderkey  NVARCHAR(10)
         , @c_Shipperkey   NVARCHAR(15)
         , @c_ohtrackingno NVARCHAR(20)
         , @c_CTUDF01      NVARCHAR(30)
         , @c_Clkcode      NVARCHAR(50)

   DECLARE @c_ReportType      NVARCHAR(10)
         , @c_ProcessType     NVARCHAR(15)
         , @c_FilePath        NVARCHAR(100)
         , @c_PrintFilePath   NVARCHAR(100)
         , @c_PrintCommand    NVARCHAR(MAX)
         , @c_WinPrinter      NVARCHAR(128)
         , @c_PrinterName     NVARCHAR(100)
         , @c_FileName        NVARCHAR(50)
         , @c_JobStatus       NVARCHAR(1)
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
         , @n_QueueID         BIGINT			--(ws01)
         , @n_starttcnt       INT
         , @c_JobID           NVARCHAR(10)
         , @c_PrintData       NVARCHAR(MAX)
         , @c_OrdNotes2       NVARCHAR(150)
         , @n_IsExists        INT           = 0
         , @c_PDFFilePath     NVARCHAR(500) = N''
         , @c_ArchivePath     NVARCHAR(200) = N''
         , @c_defaultPrn      NVARCHAR(20)  = N''
         , @c_defaultPaperprn NVARCHAR(20)  = N''
         , @n_ttlcarton       NVARCHAR(150) = 1
         , @c_getstorerkey    NVARCHAR(20)  = N''
         , @c_PackLFileName   NVARCHAR(150)
         , @c_CLFileName      NVARCHAR(150)
         , @c_PrnFileName     NVARCHAR(150)
         , @n_counter         INT           = 1
         , @n_prncopy         INT           = 1
         , @c_authority       NVARCHAR(30)  = ''   --WL01
         , @c_Option5         NVARCHAR(4000)= ''   --WL01
         , @c_MultiTNo        NVARCHAR(10)  = ''   --WL01

   CREATE TABLE #TEMPPRINTJOB
   (
      RowId       INT IDENTITY(1, 1)
    , PrnFilename NVARCHAR(50)
   )

   --WL01 S
   DECLARE @T_Carton AS TABLE (
      RowID       INT IDENTITY(1, 1)
    , TrackingNo  NVARCHAR(100)
    , CTUDF01     NVARCHAR(10)
   )
   --WL01 E

   SET @n_Err = 0
   SET @b_Success = 1
   SET @c_ErrMsg = ''
   SET @n_continue = 1
   SET @n_starttcnt = @@TRANCOUNT
   SET @c_SpoolerGroup = N''

   SET @c_Pickslipno = @c_Parm01

   SELECT TOP 1 @c_Facility = DefaultFacility
              , @c_defaultPrn = defaultprinter
              , @c_defaultPaperprn = defaultprinter_paper
   FROM RDT.RDTUser (NOLOCK)
   WHERE UserName = @c_userid

   SET @c_DocType = N''
   SELECT @c_Orderkey = ORDERS.OrderKey
        , @c_Shipperkey = ORDERS.ShipperKey
        , @c_getstorerkey = ORDERS.StorerKey
        , @c_ohtrackingno = ORDERS.TrackingNo
   FROM PackHeader (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PackHeader.OrderKey = ORDERS.OrderKey
   WHERE PackHeader.PickSlipNo = @c_Pickslipno

   IF ISNULL(@c_Storerkey, '') = ''
   BEGIN
      SET @c_Storerkey = @c_getstorerkey
   END

   --WL01 S
   EXEC dbo.nspGetRight @c_Facility = ''
                      , @c_StorerKey = @c_Storerkey
                      , @c_sku = N''
                      , @c_ConfigKey = N'Packing_Bartender_SP'
                      , @b_Success = @b_Success OUTPUT
                      , @c_authority = @c_authority OUTPUT
                      , @n_err = @n_err OUTPUT
                      , @c_errmsg = @c_errmsg OUTPUT
                      , @c_Option5 = @c_Option5 OUTPUT
   
   SELECT @c_MultiTNo = dbo.fnc_GetParamValueFromString('@c_MultiTNo', @c_Option5, @c_MultiTNo) 

   IF @c_MultiTNo = 'Y' AND TRIM(@c_authority) = 'ispPKBT12'
   BEGIN
      IF @c_Parm02 = '1' AND @c_Parm03 = '99999'   --ECOM Packing Reprint
      BEGIN
         INSERT INTO @T_Carton (TrackingNo, CTUDF01)
         SELECT PF.TrackingNo, ISNULL(CT.UDF01, '')
         FROM PACKINFO PF (NOLOCK)
         JOIN CARTONTRACK CT (NOLOCK) ON CT.TrackingNo = PF.TrackingNo
         WHERE PF.PickSlipNo = @c_Pickslipno
         GROUP BY PF.TrackingNo, ISNULL(CT.UDF01, ''), PF.CartonNo 
         ORDER BY PF.CartonNo 
      END
      ELSE
      BEGIN
         INSERT INTO @T_Carton (TrackingNo, CTUDF01)
         SELECT PF.TrackingNo, ISNULL(CT.UDF01, '')
         FROM PACKINFO PF (NOLOCK)
         JOIN CARTONTRACK CT (NOLOCK) ON CT.TrackingNo = PF.TrackingNo
         WHERE PF.PickSlipNo = @c_Pickslipno
         AND PF.CartonNo = @c_Parm02
         GROUP BY PF.TrackingNo, ISNULL(CT.UDF01, '')
      END
   END
   ELSE
   BEGIN
      SELECT @c_CTUDF01 = ISNULL(CT.UDF01, '')
      FROM dbo.CartonTrack CT WITH (NOLOCK)
      WHERE CT.TrackingNo = @c_ohtrackingno

      INSERT INTO @T_Carton (TrackingNo, CTUDF01)
      SELECT @c_ohtrackingno, @c_CTUDF01
   END
   --WL01 E

   SELECT @c_Clkcode = C.Code
   FROM dbo.CODELKUP C WITH (NOLOCK)
   WHERE C.LISTNAME = 'PDFPRNMD' AND C.Storerkey = @c_Storerkey
   AND C.Code = @c_Shipperkey   --WL01

   --select @c_DocType '@c_DocType' , @n_ttlcarton '@n_ttlcarton', @c_Shipperkey  '@c_Shipperkey', @c_PrinterID '@c_PrinterID',
   --       @c_LabelType '@c_LabelType' , @c_userid '@c_userid',@c_Parm01 '@c_Parm01',@c_Parm02 '@c_Parm02',@c_Parm03 '@c_Parm03',@c_Storerkey '@c_Storerkey'
   IF @c_Clkcode <> @c_Shipperkey
   BEGIN
      --select 'print bartender'
      EXEC isp_BT_GenBartenderCommand @cPrinterID = @c_printerid
                                    , @c_LabelType = @c_labeltype
                                    , @c_userid = @c_userid
                                    , @c_Parm01 = @c_Parm01 --pickslipno
                                    , @c_Parm02 = @c_Parm02 --carton from
                                    , @c_Parm03 = @c_Parm03 --carton to
                                    , @c_Parm04 = @c_Parm04
                                    , @c_Parm05 = @c_Parm05
                                    , @c_Parm06 = @c_Parm06
                                    , @c_Parm07 = @c_Parm07
                                    , @c_Parm08 = @c_Parm08
                                    , @c_Parm09 = @c_Parm09
                                    , @c_Parm10 = @c_Parm10
                                    , @c_StorerKey = @c_Storerkey
                                    , @c_NoCopy = @c_NoOfCopy
                                    , @c_Returnresult = 'N'
                                    , @n_err = @n_Err OUTPUT
                                    , @c_errmsg = @c_ErrMsg OUTPUT

      IF @n_Err <> 0
      BEGIN
         SET @n_continue = 3
      END

      GOTO QUIT_SP
   END
   ELSE
   BEGIN
      --WL01 S
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TC.TrackingNo, TC.CTUDF01
      FROM @T_Carton TC
      ORDER BY TC.RowID

      OPEN CUR_LOOP 
      
      FETCH NEXT FROM CUR_LOOP INTO @c_ohtrackingno, @c_CTUDF01

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_CTUDF01 = '1'
         BEGIN
            SELECT @c_FilePath = Long
                 , @c_PrintFilePath = Notes
                 , @c_ReportType = code2
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'PrtbyShipK' AND Code = @c_Shipperkey

            IF ISNULL(@c_FilePath, '') = ''
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err)
                    , @n_Err = 60011
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)
                                  + ': PDF Image Server Not Yet Setup/Enable In Codelkup Config. (ispPKBT12)' + ' ( '
                                  + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
               GOTO QUIT_SP
            END

            SET @n_IsExists = 0
            SET @c_PDFFilePath = @c_FilePath + N'\Courier_' + RTRIM(@c_ohtrackingno) + N'_SHIPLABEL.PDF'
            SET @c_ArchivePath = @c_FilePath + N'\Archive\Courier_' + RTRIM(@c_ohtrackingno) + N'_SHIPLABEL.PDF'
            EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT
            IF @n_IsExists = 0
            BEGIN
               SET @c_PDFFilePath = @c_FilePath + N'\Archive\courier_' + RTRIM(@c_ohtrackingno) + N'_SHIPLABEL.PDF'
               SET @c_ArchivePath = N''
               EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT
            END

            IF @n_IsExists = 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err)
                    , @n_Err = 60003
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': PDF filename with trackingno: ' + @c_ohtrackingno
                                  + ' not found. (ispPKBT12)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '')
                                  + ' ) '
               GOTO QUIT_SP
            END

            SELECT @c_WinPrinter = WinPrinter
                 , @c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup), '')
            FROM rdt.rdtPrinter WITH (NOLOCK)
            WHERE PrinterID = @c_defaultPrn

            IF CHARINDEX(',', @c_WinPrinter) > 0
            BEGIN
               SET @c_PrinterName = LEFT(@c_WinPrinter, (CHARINDEX(',', @c_WinPrinter) - 1))
            END
            ELSE
            BEGIN
               SET @c_PrinterName = @c_WinPrinter
            END

            IF ISNULL(@c_ArchivePath, '') = ''
            BEGIN
               SET @c_PrintCommand = N'"' + @c_PrintFilePath + N'" /t "' + @c_PDFFilePath + N'" "' + @c_PrinterName + N'"'
            END
            ELSE
            BEGIN
               SET @c_PrintCommand = N'"' + @c_PrintFilePath + N'" /t "' + @c_PDFFilePath + N'" "' + @c_PrinterName
                                     + N'" "' + @c_ArchivePath + N'"'
            END

            SET @c_JobStatus = N'9'
            SET @c_PrintJobName = N'PRINT_' + @c_ReportType
            SET @c_TargetDB = DB_NAME()

            IF @c_SpoolerGroup = ''
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 63545
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Spooler Group Not Setup for printerid: '
                               + RTRIM(@c_defaultPrn) + ' (ispPKBT12)'
               GOTO QUIT_SP
            END

            SELECT @c_IPAddress = IPAddress
                 , @c_PortNo = PortNo
                 , @c_Command = Command
                 , @c_IniFilePath = IniFilePath
            FROM rdt.rdtSpooler WITH (NOLOCK)
            WHERE SpoolerGroup = @c_SpoolerGroup

            BEGIN TRAN

            IF NOT EXISTS (  SELECT 1
                             FROM RDT.RDTMOBREC (NOLOCK)
                             WHERE UserName = @c_userid)
            BEGIN
               SELECT @n_Mobile = ISNULL(MAX(Mobile), 0) + 1
               FROM RDT.RDTMOBREC (NOLOCK)

               INSERT INTO RDT.RDTMOBREC (Mobile, UserName, Storerkey, Facility, Printer, ErrMsg, Inputkey)
               VALUES (@n_Mobile, @c_userid, @c_Storerkey, ISNULL(@c_Facility, ''), ISNULL(@c_printerid, ''), 'WMS', 0)

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_Err = 63520
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                     + ': Insert Error On Table RDT.RDTMOBREC (ispPKBT12)'
                  GOTO QUIT_SP
               END
            END
            ELSE
            BEGIN
               SELECT TOP 1 @n_Mobile = Mobile
               FROM RDT.RDTMOBREC (NOLOCK)
               WHERE UserName = @c_userid

               UPDATE RDT.RDTMOBREC WITH (ROWLOCK)
               SET Storerkey = @c_Storerkey
                 , Facility = ISNULL(@c_Facility, '')
                 , Printer = ISNULL(@c_printerid, '')
               WHERE Mobile = @n_Mobile

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_Err = 63530
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                     + ': Update Error On Table RDT.RDTMOBREC (ispPKBT12)'
                  GOTO QUIT_SP
               END
            END

            INSERT INTO RDT.RDTPrintJob (JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Parm4
                                       , Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Printer, NoOfCopy, Mobile, TargetDB
                                       , PrintData, JobType, Storerkey, Function_ID)
            VALUES (@c_PrintJobName, @c_ReportType, @c_JobStatus, '', '1', @c_Parm01, @c_Parm02, @c_Parm03, @c_Parm04
                  , @c_Parm05, @c_Parm06, @c_Parm07, @c_Parm08, @c_Parm09, @c_Parm10
                  -- ,'', '', '', '', '', '', '', '', '', ''
                  , @c_printerid, @n_prncopy, @n_Mobile, @c_TargetDB --CS03
                  , @c_PrintCommand, 'QCOMMANDER', @c_Storerkey, '999')

            SET @n_JobID = SCOPE_IDENTITY()
            SET @c_JobID = CAST(@n_JobID AS NVARCHAR(10))


            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_Err = 63540
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + ': Insert Error On Table RDT.RDTPrintJob (ispPKBT12)'
               GOTO QUIT_SP
            END

            SET @c_Application = N'QCOMMANDER'

            IF @c_Application = 'QCOMMANDER'
            BEGIN
               SET @c_Command = @c_Command + N' ' + @c_JobID

               INSERT INTO TCPSocket_QueueTask (CmdType, Cmd, StorerKey, Port, TargetDB, IP, TransmitLogKey, DataStream)
               VALUES ('CMD', @c_PrintCommand, @c_Storerkey, @c_PortNo, DB_NAME(), @c_IPAddress, @c_JobID, @c_Application)

               SET @n_QueueID = SCOPE_IDENTITY()

               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_Err = 63550
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Insert Error QCommander Task (ispPKBT12)'
                  GOTO QUIT_SP
               END

               SET @c_PrintData = N'<STX>' + N'CMD|' + CAST(@n_QueueID AS NVARCHAR(20)) + N'|' + DB_NAME() + N'|'
                                  + @c_PrintCommand + N'<ETX>'
            END

            EXEC isp_QCmd_SendTCPSocketMsg @cApplication = 'QCOMMANDER'
                                         , @cStorerKey = @c_Storerkey
                                         , @cMessageNum = @c_JobID
                                         , @cData = @c_PrintData
                                         , @cIP = @c_IPAddress
                                         , @cPORT = @c_PortNo
                                         , @cIniFilePath = @c_IniFilePath
                                         , @cDataReceived = @c_DataReceived OUTPUT
                                         , @bSuccess = @b_Success OUTPUT
                                         , @nErr = @n_Err OUTPUT
                                         , @cErrMsg = @c_ErrMsg OUTPUT


            IF @n_Err <> 0
            BEGIN
               GOTO QUIT_SP
            END

         END
         FETCH NEXT FROM CUR_LOOP INTO @c_ohtrackingno, @c_CTUDF01
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
      --WL01 E
   END

   SET @b_Success = 2

   QUIT_SP:

   IF OBJECT_ID('tempdb..#DirPDFTree') IS NOT NULL
      DROP TABLE #DirPDFTree
   
   --WL01 S
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
   --WL01 E

   IF @n_continue = 3 -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, "ispPKBT12"
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END
GRANT EXECUTE ON [dbo].[ispPKBT12] TO [NSQL]

GO