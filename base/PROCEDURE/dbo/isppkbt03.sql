SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPKBT03                                                   */
/* Creation Date: 22-Mar-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-8338 - [CN] Skechers VIP JITX Ecom Packing Courier      */
/*                     Label Printing CR                                */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/*        :                                                             */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/*31-JUL-2019  CSCHONG  1.0   Fix get wrong PDF (CS01)                  */
/*30-SEP-2019  WLChooi  1.1   WMS-10365 - Print Bartender for certain   */
/*                                        Facility only (WL01)          */
/*25-JUN-2020  WLChooi  1.2   WMS-13052 - Print SKU Label (WL02)        */
/*02-JUL-2020  WLChooi  1.3   WMS-13052 - Print SKU Label to paper      */
/*                            printer (WL03)                            */
/*11-Sep-2020  WLChooi  1.4   WMS-15133 - JITX Print ShipLabel and      */
/*                            remove PDF printing (WL04)                */
/*28-Jul-2021  WLChooi  1.5   WMS-17538 - B2B Print SF ShipLabel (WL05) */
/*29-Nov-2021  SYChua   1.6   JSM-34358 - Bug Fix for 2 types of label  */
/*                            printed on the same printer. (SY01)       */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispPKBT03]
   @c_printerid  NVARCHAR(50) = '',
   @c_labeltype  NVARCHAR(30) = '',
   @c_userid     NVARCHAR(18) = '',
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
         , @n_QueueID         INT
         , @n_starttcnt       INT
         , @c_JobID           NVARCHAR(10)
         , @c_PrintData       NVARCHAR(MAX)
         , @c_GetFacility     NVARCHAR(15)   --WL01
         , @c_IsConso         NVARCHAR(1) = ''   --WL02

   SET @n_err = 0
   SET @b_success = 1
   SET @c_errmsg = ''
   SET @n_continue = 1
   SET @n_starttcnt = @@TRANCOUNT
   SET @c_SpoolerGroup = ''

   SET @c_Pickslipno = @c_Parm01

   SELECT TOP 1 @c_Facility = DefaultFacility
   FROM RDT.RDTUser (NOLOCK)
   WHERE UserName = @c_userid

   SET @c_DocType = ''

   --WL01 Start
   --Discrete
   SELECT @c_OrderKey    = ORDERS.OrderKey
        , @c_DocType     = ORDERS.DocType
        , @c_OrdType     = ORDERS.Type
        , @c_ExtOrderkey = ORDERS.ExternOrderKey
        , @c_Shipperkey  = ORDERS.ShipperKey
        , @c_GetFacility = ORDERS.Facility
        , @c_IsConso     = 'N'   --WL02
   FROM PACKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo

   --Conso
   IF ISNULL(@c_OrderKey,'') = ''
   BEGIN
      SELECT @c_OrderKey    = ORDERS.OrderKey
           , @c_DocType     = ORDERS.DocType
           , @c_OrdType     = ORDERS.Type
           , @c_ExtOrderkey = ORDERS.ExternOrderKey
           , @c_Shipperkey  = ORDERS.ShipperKey
           , @c_GetFacility = ORDERS.Facility
           , @c_IsConso     = 'Y'   --WL02
      FROM PACKHEADER (NOLOCK)
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Loadkey = PACKHEADER.LoadKey
      JOIN ORDERS (NOLOCK) ON LPD.Orderkey = ORDERS.Orderkey
      WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
   END
   --WL01 End

   --WL02 START
   DECLARE @c_UserDefine05 NVARCHAR(18) = ''

   IF @c_labeltype = 'SKULBLSKE'
   BEGIN
      IF @c_IsConso = 'Y'
      BEGIN
         SELECT @c_UserDefine05 = MAX(ISNULL(OD.Userdefine05,''))
         FROM PACKHEADER PH (NOLOCK)
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Loadkey = PH.Loadkey
         JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = LPD.Orderkey
         JOIN ORDERDETAIL OD (NOLOCK) ON OD.Orderkey = OH.Orderkey
         WHERE PH.Pickslipno = @c_PickSlipNo AND OD.SKU = @c_Parm02
      END
      ELSE
      BEGIN
         SELECT @c_UserDefine05 = MAX(ISNULL(OD.Userdefine05,''))
         FROM PACKHEADER PH (NOLOCK)
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = PH.Orderkey
         JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = LPD.Orderkey
         JOIN ORDERDETAIL OD (NOLOCK) ON OD.Orderkey = OH.Orderkey
         WHERE PH.Pickslipno = @c_PickSlipNo AND OD.SKU = @c_Parm02
      END

      IF ISNULL(@c_UserDefine05,'') = ''   --If blank or NULL, do not print
      BEGIN
         SET @n_continue = 1
         GOTO QUIT_SP
      END

      --WL03 START (Override @c_PrinterID)
      SELECT @c_PrinterID = u.DefaultPrinter_Paper
      FROM RDT.RDTUSER u (NOLOCK)
      WHERE u.UserName = @c_UserId
      --WL03 END
   END
   --WL02 END

   IF @c_OrdType <> 'VIP' --@c_DocType = 'E'
   BEGIN
      --WL01 Start
      IF @c_DocType <> 'E'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'BTConfig'
                                                          AND Storerkey = @c_Storerkey
                                                          AND Code = @c_GetFacility )
         BEGIN
            SET @n_continue = 2 --Continue print by datawindow
            GOTO QUIT_SP
         END
         ELSE
         BEGIN
            /*     --SY01 (start)
            --WL05 S
            --Override @c_PrinterID
            SELECT @c_PrinterID = u.DefaultPrinter_Paper
            FROM RDT.RDTUSER u (NOLOCK)
            WHERE u.UserName = @c_UserId
            --WL05 E
            */     --SY01 (end)

            EXEC isp_BT_GenBartenderCommand
                     @cPrinterID = @c_PrinterID
                  ,  @c_LabelType = @c_LabelType
                  ,  @c_userid = @c_UserId
                  ,  @c_Parm01 = @c_Parm01 --pickslipno
                  ,  @c_Parm02 = @c_Parm02 --carton from
                  ,  @c_Parm03 = @c_Parm03 --carton to
                  ,  @c_Parm04 = @c_Parm04 --template code
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

            IF @n_Err <> 0
            BEGIN
               SET @n_continue = 3
            END

            --WL05 S
            IF @n_continue IN (1,2) AND @c_Shipperkey = 'SF' AND @c_LabelType <> 'SHIPLBLSKE'
            BEGIN
               --Override @c_PrinterID
               SELECT @c_PrinterID = u.DefaultPrinter
               FROM RDT.RDTUSER u (NOLOCK)
               WHERE u.UserName = @c_UserId

               EXEC isp_BT_GenBartenderCommand
                        @cPrinterID = @c_PrinterID
                     ,  @c_LabelType = 'SHIPLBLSKE'
                     ,  @c_userid = @c_UserId
                     ,  @c_Parm01 = @c_Parm01 --pickslipno
                     ,  @c_Parm02 = @c_Parm02 --carton from
                     ,  @c_Parm03 = @c_Parm03 --carton to
                     ,  @c_Parm04 = @c_Parm04 --template code
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

               IF @n_Err <> 0
               BEGIN
                  SET @n_continue = 3
               END
            END
            --WL05 E
         END

         GOTO QUIT_SP
      END --Doctype
      --WL01 End
      ELSE
      BEGIN  --WL01
         EXEC isp_BT_GenBartenderCommand
                  @cPrinterID = @c_PrinterID
               ,  @c_LabelType = @c_LabelType
               ,  @c_userid = @c_UserId
               ,  @c_Parm01 = @c_Parm01 --pickslipno
               ,  @c_Parm02 = @c_Parm02 --carton from
               ,  @c_Parm03 = @c_Parm03 --carton to
               ,  @c_Parm04 = @c_Parm04 --template code
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

         IF @n_Err <> 0
         BEGIN
            SET @n_continue = 3
         END

         GOTO QUIT_SP
      END --WL01
   END   --WL04 START
   ELSE IF @c_OrdType = 'VIP'  AND @c_DocType = 'E' AND @c_LabelType = 'SHIPUCCLBLVIP'
   BEGIN
    EXEC isp_BT_GenBartenderCommand
            @cPrinterID = @c_PrinterID
         ,  @c_LabelType = @c_LabelType
         ,  @c_userid = @c_UserId
         ,  @c_Parm01 = @c_Parm01 --pickslipno
         ,  @c_Parm02 = @c_Parm02 --carton from
         ,  @c_Parm03 = @c_Parm03 --carton to
         ,  @c_Parm04 = @c_Parm04 --template code
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

      IF @n_Err <> 0
      BEGIN
         SET @n_continue = 3
      END

      /*
      SELECT @c_FilePath = Long,
             @c_PrintFilePath = Notes,
             @c_ReportType = Code2
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'PrtbyShipK'
      AND   Code = @c_ShipperKey


      IF ISNULL(@c_FilePath,'') = '' --OR @c_NSQLValue <> '1'
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60011
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PDF Image Server Not Yet Setup/Enable In Codelkup Config. (ispPKBT03)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END

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

       SELECT TOP 1 @c_FileName = SubDirectory
       FROM #DirPDFTree
       WHERE SubDirectory like '' + @c_ExtOrderkey+ '%'     --CS01

          IF ISNULL(@c_FileName,'') = '' --OR @c_NSQLValue <> '1'
          BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60003
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PDF filename with externorderkey: ' + @c_ExtOrderkey + ' not found. (ispPKBT03)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
           END

         --SELECT @c_CreateDirTree = 'Y'

     SELECT @c_WinPrinter = WinPrinter
            ,@c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup),'')
      FROM rdt.rdtPrinter WITH (NOLOCK)
      WHERE PrinterID =  @c_PrinterID

     IF CHARINDEX(',' , @c_WinPrinter) > 0
      BEGIN
         SET @c_PrinterName = LEFT( @c_WinPrinter , (CHARINDEX(',' , @c_WinPrinter) - 1) )
      END
      ELSE
      BEGIN
         SET @c_PrinterName =  @c_WinPrinter
      END

     --set @c_FilePath = 'C:\TEMP'
     --set @c_FileName='534423_20190506022239.pdf'

      SET @c_PrintCommand = '"' + @c_PrintFilePath + '" /t "' + @c_FilePath + '\' + @c_FileName + '" "' + @c_PrinterName + '"'

       SET @c_JobStatus = '9'
       SET @c_PrintJobName = 'PRINT_' + @c_ReportType
       SET @c_TargetDB = DB_NAME()

     IF @c_SpoolerGroup = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63545
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Spooler Group Not Setup for printerid: ' + RTRIM(@c_PrinterID) + ' (ispPKBT03)'
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
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTMOBREC (ispPKBT03)'
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
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Error On Table RDT.RDTMOBREC (ispPKBT03)'
         GOTO QUIT_SP
      END
   END

         INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms
                              , Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10
                             -- , Parm11, Parm12, Parm13, Parm14, Parm15, Parm16, Parm17, Parm18, Parm19, Parm20                      --(Wan06)
                              , Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, Storerkey, Function_ID)
   VALUES(@c_PrintJobName, @c_ReportType, @c_JobStatus, '', '1'
         ,@c_Parm01, @c_Parm02, @c_Parm03, @c_Parm04, @c_Parm05, @c_Parm06, @c_Parm07, @c_Parm08, @c_Parm09, @c_Parm10
        -- ,'', '', '', '', '', '', '', '', '', ''
         ,@c_PrinterID, 1, @n_Mobile, @c_TargetDB
        , @c_PrintCommand, 'QCOMMANDER', @c_Storerkey, '999')
   --(Wan04) - END

   SET @n_JobID = SCOPE_IDENTITY()
   SET @c_JobID       = CAST( @n_JobID AS NVARCHAR( 10))

   IF @@ERROR <> 0
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 63540
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTPrintJob (ispPKBT03)'
      GOTO QUIT_SP
   END

   SET @c_Application = 'QCOMMANDER'

   IF @c_Application = 'QCOMMANDER'
      BEGIN
         SET @c_Command = @c_Command + ' ' + @c_JobID

         -- Insert task
         -- SWT01
      -- select 'insert queuetask'
         INSERT INTO TCPSocket_QueueTask (CmdType, Cmd, StorerKey, Port, TargetDB, IP, TransmitLogKey,datastream)
         VALUES ('CMD', @c_PrintCommand, @c_StorerKey, @c_PortNo, DB_NAME(), @c_IPAddress, @c_JobID,@c_Application )

         SET @n_QueueID = SCOPE_IDENTITY()

       --select @n_QueueID '@n_QueueID'

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63550
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error QCommander Task (ispPKBT03)'
            GOTO QUIT_SP
         END

        --set @c_PrintCommand "C:\Program Files\Foxit Software\Foxit Reader\Foxit Reader.exe" /t "C:\TEMP\534423_20190506022239.pdf" "CN_18354_ZebraGK888t_TEST"'
         -- <STX>CMD|855377|CNWMS|D:\RDTSpooler\rdtprint.exe 2668351<ETX>
         SET @c_PrintData =
            '<STX>' +
               'CMD|' +
               CAST( @n_QueueID AS NVARCHAR( 20)) + '|' +
               DB_NAME() + '|' +
               @c_PrintCommand +
            '<ETX>'
      END

      -- Call Qcommander

   --  select @c_PrintData '@c_PrintData'
      IF @c_errmsg = ''   --WL04 If there is error msg, do not send tcpsocket msg
      BEGIN
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
      END   --WL04

      -- select @n_err '@n_err'

      IF @n_err <> 0
      BEGIN
         GOTO QUIT_SP
      END

      QCMD_END:
  -- END


       -- EXEC  isp_PrintToRDTSpooler
       --  @c_ReportType = 'INVPRNPDF' ,
       --  @c_Storerkey      = @c_Storerkey,
       --  @n_Noofparam      = 0,
       --  @c_Param01        = @c_Parm01,
       --  @c_Param02        = @c_Parm02,
       --  @c_Param03        = @c_Parm03,
       --  @c_Param04        = @c_Parm04,
       --  @c_Param05        = @c_Parm05,
       --  @c_Param06        = @c_Parm06,
       --  @c_Param07        = @c_Parm07,
       --  @c_Param08        = @c_Parm08,
       --  @c_Param09        = @c_Parm09,
       --  @c_Param10        = @c_Parm10,
       --  @n_Noofcopy       = 1,
       --  @c_UserName       = @c_UserId,
       --  @c_Facility       = '',
       --  @c_PrinterID      = @c_PrinterID,
       --  @c_Datawindow     = '',
       --  @c_IsPaperPrinter = 'N',
       --  @c_JobType        = 'QCOMMANDER',
       --  @c_PrintData      = @c_PrintCommand,
       --  @n_Function_ID    = 999,
       --  @b_success        = @b_success   OUTPUT ,
   --        @n_err            = @n_err       OUTPUT ,
   --        @c_errmsg         = @c_errmsg    OUTPUT



   --IF @b_success = 0
   --BEGIN
   --   SET @n_Continue=3
   --   SET @n_err = 60012
   --   SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Error Executing isp_PrintToRDTSpooler. '
   --                 + '( ' + @c_errmsg + ' ). (ispPKBT03)'
   --   GOTO QUIT_SP
   --END
      END
      */
   END
   --WL04 END

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_PrintToRDTSpooler"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   --WL01 Start
   ELSE IF @n_continue = 2
   BEGIN
      SET @b_success = 2
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
   --WL01 End
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

GO