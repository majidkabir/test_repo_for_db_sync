SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  

/******************************************************************************/  
/* Copyright: IDS                                                             */  
/* Purpose: For BarTender Generic Store Procedure                             */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2013-06-28 1.0  CSCHONG    Created                                         */  
/* 2013-09-11 2.0  CSCHONG    Add in error msg and number return (CS01)       */  
/* 2013-09-23 3.0  CSCHONG    Add in new parameter for no of copy (CS02)      */  
/* 2013-10-01 4.0  CSCHONG    Add in Storerkey in label config table (CS03)   */  
/* 2013-10-07 5.0  CSCHONG    Add in c_Returnresult parameter  (CS04)         */  
/* 2013-10-09 6.0  CSCHONG    PrinterName:WinPrinter 1st delimiter value(CS05)*/  
/* 2013-10-10 7.0  CSCHONG    Default userid to SUSER_SNAME() if NULL (CS06)  */  
/* 2013-11-07 8.0  CSCHONG    For RDT get printer from rdtmobile  (CS07)      */  
/* 2013-11-19 9.0  CSCHONG    Create text file send by TCP IP  (CS08)         */  
/* 2013-11-29 10.0 CSCHONG    Remove wait for delay 1 sec to increase print   */  
/*                            performance   (CS09)                            */  
/* 2013-12-05 11.0 CSCHONG    create cursor to loop sub SP (CS10)             */  
/* 2014-01-28 12.0 CSCHONG    Cater for PB RCM retrun no record error (CS11)  */  
/* 2014-02-11 13.0 CSCHONG    Increase lenght noofcopy to 5 (CS12)            */  
/* 2014-04-11 14.0 CSCHONG    Remove LTRIM for SOS298740 (CS13)               */  
/* 2014-05-14 15.0 CSCHONG    FIX PB view report error (CS14)                 */  
/* 2014-05-27 15.1 CSCHONG    FIX RDT return error (C15)                      */  
/* 2014-07-17 16.0 CSCHONG    Add counter in printername (CS16)               */  
/* 2014-08-01 17.0 CSCHONG    Add Storerkey in OUTLOG (CS17)                  */  
/* 2014-09-10 18.0 CSCHONG    Fix double code  delimeter bugs (CS18)          */  
/* 2014-10-14 19.0 CSCHONG    increase counter lenght to 10 (CS19)            */  
/******************************************************************************/  
-- Duplicate from isp_BT_GenBartenderCommand (For TH MCD Storer only)  
CREATE PROC [RDT].[ispRdtBartenderCmd](  
      @cPrinterID     NVARCHAR(50)  
     ,@c_LabelType    NVARCHAR(30)  
     ,@c_userid       NVARCHAR(18)  
     ,@c_Parm01       NVARCHAR(60)  
     ,@c_Parm02       NVARCHAR(60)  
     ,@c_Parm03       NVARCHAR(60)  
     ,@c_Parm04       NVARCHAR(60)  
     ,@c_Parm05       NVARCHAR(60)  
     ,@c_Parm06       NVARCHAR(60)  
     ,@c_Parm07       NVARCHAR(60)  
     ,@c_Parm08       NVARCHAR(60)  
     ,@c_Parm09       NVARCHAR(60)  
     ,@c_Parm10       NVARCHAR(60)  
     ,@c_Storerkey    NVARCHAR(15) =''            --CS03  
     ,@c_NoCopy       CHAR(5)                     --CS02 --CS12  
     ,@b_Debug        CHAR(1)=0  
     ,@c_Returnresult NCHAR(1)='N'                --CS04  
     ,@n_err          INT = 0             OUTPUT      --CS01  
     ,@c_errmsg       NVARCHAR(250)=''    OUTPUT      --CS01  
  
  
  )  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
  CREATE TABLE #t_BartenderCommand  
   (   [ID]    [INT] IDENTITY(1,1) NOT NULL  
      ,PARM01   NVARCHAR(60)  
      ,PARM02  NVARCHAR(60)  
      ,PARM03  NVARCHAR(60)  
      ,PARM04  NVARCHAR(60)  
      ,PARM05  NVARCHAR(60)  
      ,PARM06  NVARCHAR(60)  
      ,PARM07  NVARCHAR(60)  
      ,PARM08  NVARCHAR(60)  
      ,PARM09  NVARCHAR(60)  
      ,PARM10  NVARCHAR(60)  
      ,KEY01   NVARCHAR(60)  
      ,KEY02   NVARCHAR(60)  
      ,KEY03   NVARCHAR(60)  
      ,KEY04   NVARCHAR(60)  
      ,KEY05   NVARCHAR(60)  
   )  
  
  CREATE TABLE [#Result] (  
      [ID]    INT ,  
      [Col01] [NVARCHAR] (80) NULL,  
      [Col02] [NVARCHAR] (80) NULL,  
      [Col03] [NVARCHAR] (80) NULL,  
      [Col04] [NVARCHAR] (80) NULL,  
      [Col05] [NVARCHAR] (80) NULL,  
      [Col06] [NVARCHAR] (80) NULL,  
      [Col07] [NVARCHAR] (80) NULL,  
      [Col08] [NVARCHAR] (80) NULL,  
      [Col09] [NVARCHAR] (80) NULL,  
      [Col10] [NVARCHAR] (80) NULL,  
      [Col11] [NVARCHAR] (80) NULL,  
      [Col12] [NVARCHAR] (80) NULL,  
      [Col13] [NVARCHAR] (80) NULL,  
      [Col14] [NVARCHAR] (80) NULL,  
      [Col15] [NVARCHAR] (80) NULL,  
      [Col16] [NVARCHAR] (80) NULL,  
      [Col17] [NVARCHAR] (80) NULL,  
      [Col18] [NVARCHAR] (80) NULL,  
      [Col19] [NVARCHAR] (80) NULL,  
      [Col20] [NVARCHAR] (80) NULL,  
      [Col21] [NVARCHAR] (80) NULL,  
      [Col22] [NVARCHAR] (80) NULL,  
      [Col23] [NVARCHAR] (80) NULL,  
      [Col24] [NVARCHAR] (80) NULL,  
      [Col25] [NVARCHAR] (80) NULL,  
      [Col26] [NVARCHAR] (80) NULL,  
      [Col27] [NVARCHAR] (80) NULL,  
      [Col28] [NVARCHAR] (80) NULL,  
      [Col29] [NVARCHAR] (80) NULL,  
      [Col30] [NVARCHAR] (80) NULL,  
      [Col31] [NVARCHAR] (80) NULL,  
      [Col32] [NVARCHAR] (80) NULL,  
      [Col33] [NVARCHAR] (80) NULL,  
      [Col34] [NVARCHAR] (80) NULL,  
      [Col35] [NVARCHAR] (80) NULL,  
      [Col36] [NVARCHAR] (80) NULL,  
      [Col37] [NVARCHAR] (80) NULL,  
      [Col38] [NVARCHAR] (80) NULL,  
      [Col39] [NVARCHAR] (80) NULL,  
      [Col40] [NVARCHAR] (80) NULL,  
      [Col41] [NVARCHAR] (80) NULL,  
      [Col42] [NVARCHAR] (80) NULL,  
      [Col43] [NVARCHAR] (80) NULL,  
      [Col44] [NVARCHAR] (80) NULL,  
      [Col45] [NVARCHAR] (80) NULL,  
      [Col46] [NVARCHAR] (80) NULL,  
      [Col47] [NVARCHAR] (80) NULL,  
      [Col48] [NVARCHAR] (80) NULL,  
      [Col49] [NVARCHAR] (80) NULL,  
      [Col50] [NVARCHAR] (80) NULL,  
      [Col51] [NVARCHAR] (80) NULL,  
      [Col52] [NVARCHAR] (80) NULL,  
      [Col53] [NVARCHAR] (80) NULL,  
      [Col54] [NVARCHAR] (80) NULL,  
      [Col55] [NVARCHAR] (80) NULL,  
      [Col56] [NVARCHAR] (80) NULL,  
      [Col57] [NVARCHAR] (80) NULL,  
      [Col58] [NVARCHAR] (80) NULL,  
      [Col59] [NVARCHAR] (80) NULL,  
      [Col60] [NVARCHAR] (80) NULL  
     )  
  
   DECLARE @cSQL            NVARCHAR(MAX)  
          ,@c_KEY01         NVARCHAR(60)  
          ,@c_KEY02         NVARCHAR(60)  
          ,@c_KEY03         NVARCHAR(60)  
          ,@c_KEY04         NVARCHAR(60)  
          ,@c_KEY05         NVARCHAR(60)  
          ,@c_TemplatePath  NVARCHAR(1000)  
          ,@c_SubSP         NVARCHAR(1000)  
          ,@c_PrintJobName  NVARCHAR(500)  
          ,@c_PrinterName   NVARCHAR(150)  
          ,@c_CopyPrint     NVARCHAR(100)    --CS02  
          ,@c_Copy          NVARCHAR(5)      --CS02  --CS12  
          ,@c_Result        NVARCHAR(200)    --CS04  
          ,@c_GetUserID     NVARCHAR(18)      --CS06  
          ,@n_CntUser       INT               --CS06  
          ,@n_StartTrnCnt   INT  
          ,@c_counter       INT  
          ,@n_CmdCounter    INT              --CS16  
          ,@n_PrnCounter    INT              --CS16  
          ,@n_CntBarRec     INT              --CS16  
  
   SET @n_StartTrnCnt = @@TRANCOUNT  
  
   DECLARE @c_BartenderCommand  NVARCHAR(4000)  
          ,@c_MessageNum_Out    NVARCHAR(20)  
          ,@b_Success           INT  
          ,@c_DPC_MessageNo     NVARCHAR(20)  
          ,@c_IniFilePath       NVARCHAR(100)  
          ,@c_RemoteEndPoint    NVARCHAR(50)  
          ,@c_LocalEndPoint     NVARCHAR(50)  
          ,@c_ReceiveMessage    NVARCHAR(4000)  
          ,@c_vbErrMsg          NVARCHAR(4000)  
          ,@n_Status_Out        INT  
          ,@n_SerialNo_Out      INT  
          ,@c_BT_Parm01         NVARCHAR(60)  
          ,@c_BT_Parm02         NVARCHAR(60)  
          ,@c_BT_Parm03         NVARCHAR(60)  
          ,@c_BT_Parm04         NVARCHAR(60)  
          ,@c_BT_Parm05         NVARCHAR(60)  
          ,@c_BT_Parm06         NVARCHAR(60)  
          ,@c_BT_Parm07         NVARCHAR(60)  
          ,@c_BT_Parm08         NVARCHAR(60)  
          ,@c_BT_Parm09         NVARCHAR(60)  
          ,@c_BT_Parm10         NVARCHAR(60)  
          ,@c_tempfilepath      NVARCHAR(215)   --CS08  
          ,@c_FullText          NVARCHAR(4000)   --CS08  
          ,@c_HeaderText        NVARCHAR(4000)   --CS08  
          ,@c_Filename          NVARCHAR(100)   --CS08  
          ,@n_WorkFolderExists  INT             --CS08  
          ,@c_WorkFilePath      NVARCHAR(215)   --CS08  
          ,@c_SqlString         NVARCHAR(2000)  --CS08  
          ,@c_NewLineChar       CHAR(2)         --CS08  
          ,@c_GetFullText       NVARCHAR(4000)  --CS08  
          ,@n_cnt               INT  
          ,@n_cntbartender      INT  
          ,@c_OutLog            NVARCHAR(4000) --CS11  
  
   DECLARE @d_Trace_StartTime  DATETIME,  
           @d_Trace_EndTime    DATETIME,  
           @n_Trace_NoOfLabel  INT,  
           @d_Trace_Step1      DATETIME,  
           @c_Trace_Step1      NVARCHAR(20),  
           @c_Trace_Step2      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20)  
  
  Declare  @c_ID     NVARCHAR (80),  
           @c_Col01  NVARCHAR (80),  
           @c_Col02  NVARCHAR (80),  
           @c_Col03  NVARCHAR (80),  
           @c_Col04  NVARCHAR (80),  
           @c_Col05  NVARCHAR (80),  
           @c_Col06  NVARCHAR (80),  
           @c_Col07  NVARCHAR (80),  
           @c_Col08  NVARCHAR (80),  
           @c_Col09  NVARCHAR (80),  
           @c_Col10  NVARCHAR (80),  
           @c_Col11  NVARCHAR (80),  
           @c_Col12  NVARCHAR (80),  
           @c_Col13  NVARCHAR (80),  
           @c_Col14  NVARCHAR (80),  
           @c_Col15  NVARCHAR (80),  
           @c_Col16  NVARCHAR (80),  
           @c_Col17  NVARCHAR (80),  
           @c_Col18  NVARCHAR (80),  
           @c_Col19  NVARCHAR (80),  
           @c_Col20  NVARCHAR (80),  
           @c_Col21  NVARCHAR (80),  
           @c_Col22  NVARCHAR (80),  
           @c_Col23  NVARCHAR (80),  
           @c_Col24  NVARCHAR (80),  
           @c_Col25  NVARCHAR (80),  
           @c_Col26  NVARCHAR (80),  
           @c_Col27  NVARCHAR (80),  
           @c_Col28  NVARCHAR (80),  
           @c_Col29  NVARCHAR (80),  
           @c_Col30  NVARCHAR (80),  
           @c_Col31  NVARCHAR (80),  
           @c_Col32  NVARCHAR (80),  
           @c_Col33  NVARCHAR (80),  
           @c_Col34  NVARCHAR (80),  
           @c_Col35  NVARCHAR (80),  
           @c_Col36  NVARCHAR (80),  
           @c_Col37  NVARCHAR (80),  
           @c_Col38  NVARCHAR (80),  
           @c_Col39  NVARCHAR (80),  
           @c_Col40  NVARCHAR (80),  
           @c_Col41  NVARCHAR (80),  
           @c_Col42  NVARCHAR (80),  
           @c_Col43  NVARCHAR (80),  
           @c_Col44  NVARCHAR (80),  
           @c_Col45  NVARCHAR (80),  
           @c_Col46  NVARCHAR (80),  
           @c_Col47  NVARCHAR (80),  
           @c_Col48  NVARCHAR (80),  
           @c_Col49  NVARCHAR (80),  
           @c_Col50  NVARCHAR (80),  
           @c_Col51  NVARCHAR (80),  
           @c_Col52  NVARCHAR (80),  
           @c_Col53  NVARCHAR (80),  
           @c_Col54  NVARCHAR (80),  
           @c_Col55  NVARCHAR (80),  
           @c_Col56  NVARCHAR (80),  
           @c_Col57  NVARCHAR (80),  
           @c_Col58  NVARCHAR (80),  
           @c_Col59  NVARCHAR (80),  
           @c_Col60  NVARCHAR (80)  
  
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @n_Trace_NoOfLabel = 0  
  
   SET @cSQL = ''  
   SET @c_Result = ''  
   SET @c_PrinterName = ''  
   SET @n_err = 0  
   SET @c_errmsg = ''  
   SET @c_Filename = ''  
   SET @c_FullText = ''  
   SET @c_NewLineChar = CHAR(13) + CHAR(10)  
   SET @c_OutLog = ''  
   SET @n_CmdCounter = 0  
  
   WHILE @@TRANCOUNT > 0  
   COMMIT TRAN  
  
   IF @b_Debug = '1'  
   BEGIN  
       PRINT CONVERT(NVARCHAR(20) ,GETDATE() ,120)  
   END  
  
   SELECT @n_err = 0  
         ,@c_errmsg = ''  
  
  
   /*CS01 End*/  
  
   SELECT @cSQL = SQL_Select  
   FROM   BartenderCmdConfig WITH (NOLOCK)  
   WHERE  LabelType = @c_LabelType  
  
  
   /*CS01 Start*/  
   IF @cSQL IS NULL OR @cSQL = ''  
   BEGIN  
       SELECT @n_err = 82553  
       SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5) ,@n_err) + ': SQL Select field no set up for label type ' + @c_LabelType +  
              ' (ispRdtBartenderCmd) '  
  
       SET @c_result = 'label type : ' + @c_LabelType + '' + @c_errmsg --CS04  
  
       IF @c_Returnresult = 'Y'  
       BEGIN  
           SELECT @c_result AS c_Result  
       END  
  
       GOTO QUIT  
   END  
   /*CS01 End*/  
  
   IF @b_debug = 1  
   BEGIN  
      PRINT @cSQL  
      PRINT 'PrinterId ' +  @cPrinterID  
   END  
  
   DECLARE @n_IsRDT INT                       --CS07  
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT       --CS07  
  
   IF @b_debug='1'  
   BEGIN  
    PRINT ' Check RDT user : ' + convert (varchar(1),@n_IsRDT)  
    PRINT 'PrinterId ' +  @cPrinterID  
   END  
  
   IF ISNULL(@cPrinterID ,'') <> ''  
   BEGIN  
       SELECT @c_Printername = LEFT(winprinter ,CHARINDEX(',' ,winprinter + ',') -1) --(CS05)  
       FROM   rdt.rdtprinter WITH (NOLOCK)  
       WHERE  PrinterID = @cPrinterID  
   END  
     -- ELSE  
   IF ISNULL(@cPrinterID ,'') = '' AND ISNULL(@c_userID ,'') <> ''  
   BEGIN  
       SELECT @n_CntUser = COUNT(1)  
       FROM   RDT.RdtUser WITH (NOLOCK)  
       WHERE  username = @c_userID  
  
       IF @n_CntUser = 0  
       BEGIN  
           INSERT INTO rdt.RDTUser  
             (  
               UserName              ,PASSWORD           ,FullName  
              ,DefaultStorer         ,DefaultFacility    ,DefaultLangCode  
              ,DefaultMenu           ,DefaultUOM         ,DefaultPrinter  
              ,DefaultPrinter_Paper  ,sqluseradddate  
             )  
           VALUES  
             (@c_userID           ,'EXceedUser'    ,@c_userID  
              ,''                 ,''              ,'ENG'  
              ,5                  ,'6'             ,''  
              ,''                 ,GETDATE() )  
       END  
  
       IF @n_IsRDT <> 1  --CS07  
       BEGIN  
       SELECT @c_Printername = LEFT(RP.winprinter ,CHARINDEX(',' ,RP.winprinter + ',') -1), --CS05  
              @cPrinterID = RP.PrinterID  
       FROM   rdt.rdtuser RU WITH (NOLOCK)  
              JOIN rdt.rdtprinter RP WITH (NOLOCK)  
              ON  RU.defaultPrinter = RP.PrinterID  
       WHERE  RU.Username = @c_userID  
       END  
       /*CS07 Start*/  
       ELSE  
       BEGIN  
       SELECT @c_Printername = Left(RP.winprinter, CharIndex(',', RP.winprinter + ',')-1),  --CS05  
              @cPrinterID = RP.PrinterID  
       FROM rdt.RDTMOBREC RMR WITH (NOLOCK) JOIN rdt.rdtprinter RP WITH (NOLOCK)  
       ON RMR.Printer = RP.PrinterID  
       WHERE RMR.Username = @c_userID  
       END  
       /*CS07 end*/  
   END  
  
   /*CS04 End*/  
   /*CS06 Start*/  
   IF ISNULL(@c_userID ,'') = ''  
   BEGIN  
       SET @c_GetUserID = SUSER_SNAME()  
       SET @c_userID = @c_GetUserID  
  
       SELECT @n_CntUser = COUNT(1)  
       FROM   RDT.RdtUser WITH (NOLOCK)  
       WHERE  username = @c_GetUserID  
  
       IF @n_CntUser = 0  
       BEGIN  
           INSERT INTO rdt.RDTUser  
             (  
               UserName  
              ,PASSWORD  
              ,FullName  
              ,DefaultStorer  
              ,DefaultFacility  
              ,DefaultLangCode  
              ,DefaultMenu  
              ,DefaultUOM  
              ,DefaultPrinter  
              ,DefaultPrinter_Paper  
              ,sqluseradddate  
             )  
           VALUES  
             (  
               @c_GetUserID  
              ,'EXceedUser'  
              ,@c_GetUserID  
              ,''  
              ,''  
              ,'ENG'  
              ,5  
              ,'6'  
              ,''  
              ,''  
              ,GETDATE()  
             )  
  
           IF ISNULL(@cPrinterID ,'') = ''  
           BEGIN  
  
              IF @n_IsRDT <> 1     --CS07  
              BEGIN  
  
              SELECT @c_Printername = LEFT(RP.winprinter ,CHARINDEX(',' ,RP.winprinter + ',') -1), --CS05  
                     @cPrinterID = RP.PrinterID  
              FROM   rdt.rdtuser RU WITH (NOLOCK)  
              JOIN rdt.rdtprinter RP WITH (NOLOCK) ON  RU.defaultPrinter = RP.PrinterID  
              WHERE  RU.Username = @c_GetUserID  
  
              END  
              /*CS07 Start*/  
              ELSE  
              BEGIN  
  
              SELECT @c_Printername = Left(RP.winprinter, CharIndex(',', RP.winprinter + ',')-1),  --CS05  
                     @cPrinterID = RP.PrinterID  
              FROM rdt.RDTMOBREC RMR WITH (NOLOCK) JOIN rdt.rdtprinter RP WITH (NOLOCK)  
              ON RMR.Printer = RP.PrinterID  
              WHERE RMR.Username = @c_GetUserID  
  
            END  
            /*CS07 end*/  
           END  
       END  
       ELSE  
       IF ISNULL(@cPrinterID ,'') = ''  
       BEGIN  
  
           IF @n_IsRDT <> 1     --CS07  
           BEGIN  
  
           SELECT @c_Printername = LEFT(RP.winprinter ,CHARINDEX(',' ,RP.winprinter + ',') -1), --CS05  
                  @cPrinterID = RP.PrinterID  
           FROM   rdt.rdtuser RU WITH (NOLOCK)  
           JOIN rdt.rdtprinter RP WITH (NOLOCK) ON RU.defaultPrinter = RP.PrinterID  
           WHERE  RU.Username = @c_GetUserID  
  
           END  
          /*CS07 Start*/  
          ELSE  
          BEGIN  
  
          SELECT @c_Printername = Left(RP.winprinter, CharIndex(',', RP.winprinter + ',')-1),  --CS05  
                 @cPrinterID = RP.PrinterID  
          FROM rdt.RDTMOBREC RMR WITH (NOLOCK) JOIN rdt.rdtprinter RP WITH (NOLOCK)  
          ON RMR.Printer = RP.PrinterID  
          WHERE RMR.Username = @c_GetUserID  
  
          END  
      /*CS07 end*/  
       END  
   END  
   /*CS06 END*/  
   /*CS01 Start*/  
  
 IF @b_debug='1'  
 BEGIN  
   PRINT 'Printer ' +  @c_Printername + ' with userid ' +  @c_userID  
 END  
  
  IF ISNULL(RTRIM(@c_Printername),'') = '' OR ISNULL(RTRIM(@cPrinterID),'') = ''  
  BEGIN  
      SELECT @n_err = 82554  
      SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': Printer not setup for printer ID : ' + @cPrinterID  
            + ' with username ' + @c_userID +  ' (ispRdtBartenderCmd) '  
      SET @c_result = @c_errmsg        --CS04  
  
      IF @c_Returnresult = 'Y'  
      BEGIN  
         SELECT @c_result as c_Result  
      END  
  
      GOTO QUIT  
  END  
   /*CS01 End*/  
  
   /* Assign Different Path/TCP Port base on Printer Group */  
   -----------------------------------------------------------  
   SET @c_IniFilePath = ''  
   SET @c_RemoteEndPoint = ''  
  
   SELECT TOP 1  
          @c_IniFilePath = c.UDF01  
         ,@c_RemoteEndPoint = c.Long  
   FROM   CODELKUP c WITH (NOLOCK)  
   JOIN   rdt.RDTPrinter prt WITH (NOLOCK) ON prt.PrinterGroup = C.Storerkey  
   WHERE  ListName = 'TCPClient'  
   AND    c.Short = 'BARTENDER'  
   AND    prt.PrinterID = @cPrinterID  
  
   IF @b_debug = '1'  
   BEGIN  
   PRINT ''  
   END  
  
   IF ISNULL(RTRIM(@c_RemoteEndPoint), '') = ''  
   BEGIN  
      SELECT TOP 1  
             @c_IniFilePath = c.UDF01  
            ,@c_RemoteEndPoint = c.Long  
      FROM   CODELKUP c WITH (NOLOCK)  
      WHERE  ListName = 'TCPClient'  
      AND    c.Short = 'BARTENDER'  
      AND    (StorerKey = '' OR StorerKey IS NULL)  
   END  
  
      /*CS01 start*/  
   IF @c_IniFilePath IS NULL OR @c_IniFilePath = ''  
   BEGIN  
       SELECT @n_err = 82551  
       SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5) ,@n_err) + ': CODELKUP INI file path Not Setup. (ispRdtBartenderCmd) '  
       SET @c_result = @c_result + @c_errmsg --CS04  
                                             --GOTO QUIT  
   END  
  
   IF @c_RemoteEndPoint IS NULL  OR @c_RemoteEndPoint = ''  
   BEGIN  
       SELECT @n_err = 82552  
       SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5) ,@n_err) + ': CODELKUP Remote End point Not setup. (ispRdtBartenderCmd) '  
       SET @c_result = @c_errmsg --CS04  
  
       IF @c_Returnresult = 'Y'  
       BEGIN  
           SELECT @c_result AS c_Result  
       END  
  
       GOTO QUIT  
   END  
  
   ------------------------------------------------------------  
   IF ISNULL(@c_NoCopy ,'') = ''  
  BEGIN  
       SET @c_Copy = '1'  
   END  
   ELSE  
   BEGIN  
       SET @c_Copy = @c_NoCopy  
   END  
  
--  
--   IF @b_Debug ='1'  
--   BEGIN  
--      PRINT 'Copy ' +  @c_Copy  
--      PRINT 'Errmsg ' +  @c_result  
--   END  
  
  
   SET @c_CopyPrint = 'C='+ @c_Copy  
  
  
   INSERT INTO #t_BartenderCommand  
   EXEC sp_executesql @cSQL,  
        N'@Parm01 nvarchar(60) ,@Parm02 nvarchar(60) ,@Parm03 nvarchar(60)  
       ,@Parm04 nvarchar(60)   ,@Parm05 nvarchar(60) ,@Parm06 nvarchar(60)  
       ,@Parm07 nvarchar(60)   ,@Parm08 nvarchar(60) ,@Parm09 nvarchar(60)  
       ,@Parm10 nvarchar(60)   ,@NCopy nvarchar(10)'  
       ,@c_Parm01, @c_Parm02 ,@c_Parm03  
       ,@c_Parm04, @c_Parm05 ,@c_Parm06  
       ,@c_Parm07, @c_Parm08 ,@c_Parm09  
       ,@c_Parm10,@c_NoCopy  
  
   SET @d_Trace_Step1 = GETDATE()  
  
   SELECT @n_CntBarRec = count(1)  
          FROM #t_BartenderCommand  
  
   DECLARE CUR_BartenderCommandLoop CURSOR LOCAL FAST_FORWARD READ_ONLY  
   FOR  
       SELECT ID,PARM01  ,PARM02 ,PARM03  
             ,PARM04  ,PARM05 ,PARM06  
             ,PARM07  ,PARM08 ,PARM09  
             ,PARM10  
             ,KEY01   ,KEY02  ,KEY03  
             ,KEY04   ,KEY05  
       FROM   #t_BartenderCommand  
  
     IF @b_debug='1'  
     BEGIN  
     SELECT 'Bartender'  
     SELECT * FROM #t_BartenderCommand  
     END  
  
   OPEN CUR_BartenderCommandLoop  
  
   FETCH NEXT FROM CUR_BartenderCommandLoop  
      INTO @n_CmdCounter,@c_BT_Parm01, @c_BT_Parm02, @c_BT_Parm03,  
           @c_BT_Parm04, @c_BT_Parm05, @c_BT_Parm06,  
           @c_BT_Parm07, @c_BT_Parm08, @c_BT_Parm09,  
           @c_BT_Parm10, @c_KEY01, @c_KEY02,  
           @c_KEY03, @c_KEY04, @c_KEY05  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
  
  
      SELECT @c_TemplatePath = TemplatePath  
            ,@c_SubSP = StoreProcedure  
         --   ,@c_tempfilepath = filepath  
      FROM   BartenderLabelCfg WITH (NOLOCK)  
      WHERE  LabelType = @c_LabelType  
      AND    Key01 = CASE  
                        WHEN ISNULL(@c_KEY01 ,'') <> '' THEN @c_KEY01  
                        ELSE Key01  
                     END  
      AND    Key02 = CASE  
                        WHEN ISNULL(@c_KEY02 ,'') <> '' THEN @c_KEY02  
                        ELSE Key02  
                     END  
      AND    Key03 = CASE  
                        WHEN ISNULL(@c_KEY03 ,'') <> '' THEN @c_KEY03  
                        ELSE Key03  
                     END  
      AND    Key04 = CASE  
                        WHEN ISNULL(@c_KEY04 ,'') <> '' THEN @c_KEY04  
                        ELSE Key04  
                     END  
      AND    Key05 = CASE  
                        WHEN ISNULL(@c_KEY05 ,'') <> '' THEN @c_KEY05  
                        ELSE Key05  
                     END  
      AND    StorerKey = ISNULL(@c_storerkey ,'')  
  
  
      IF @b_Debug = '1'  
      BEGIN  
         PRINT  'Template Path ' + @c_TemplatePath  + ' And file path ' + @c_tempfilepath  
      END  
  
     /*CS01 Start*/  
     IF @c_TemplatePath IS NULL OR @c_TemplatePath = ''  --OR  ISNULL(@c_tempfilepath,'')=''  
     BEGIN  
        SELECT @n_err = 82555  
        SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': Label template path not setup for label type  : ' + @c_LabelType + ' (ispRdtBartenderCmd) '  
        SET @c_result = @c_errmsg        --CS04  
  
        IF @c_Returnresult = 'Y'  
        BEGIN  
           SELECT @c_result as c_Result  
        END  
  
         GOTO QUIT  
      END  
  
     IF @c_SubSP IS NULL OR @c_SubSP = ''  
     BEGIN  
         SELECT @n_err = 82556  
         SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': sub SP not setup for label type  : ' + @c_LabelType + ' (ispRdtBartenderCmd) '  
         SET @c_result = @c_errmsg        --CS04  
  
         IF @c_Returnresult = 'Y'  
         BEGIN  
            SELECT @c_result as c_Result  
         END  
         GOTO QUIT  
     END  
  
     /*CS01 End*/  
  
        SET @c_SqlString = N' Exec ' + @c_SubSP + ' @Parm01,@Parm02 ,@Parm03,@Parm04,@Parm05,@Parm06,@Parm07,@Parm08,@Parm09,@Parm10'  
  
        IF @b_debug = '1'  
        BEGIN  
          Print @c_SqlString  
        END  
  
--       SET @n_StartTrnCnt = @@TRANCOUNT  
--  
--       WHILE @@TRANCOUNT > 0  
--       COMMIT TRAN  
  
      -- BEGIN TRAN  
  
        TRUNCATE TABLE #Result  
  
        INSERT INTO #Result  
        EXEC sp_executesql @c_SqlString,  
        N'@Parm01 nvarchar(60) ,@Parm02 nvarchar(60) ,@Parm03 nvarchar(60)  
       ,@Parm04 nvarchar(60)   ,@Parm05 nvarchar(60) ,@Parm06 nvarchar(60)  
       ,@Parm07 nvarchar(60)   ,@Parm08 nvarchar(60) ,@Parm09 nvarchar(60)  
       ,@Parm10 nvarchar(60)'  
       ,@Parm01 = @c_BT_Parm01  
       ,@Parm02 = @c_BT_Parm02  
       ,@Parm03 = @c_BT_Parm03  
       ,@Parm04 = @c_BT_Parm04  
       ,@Parm05=  @c_BT_Parm05  
       ,@Parm06 = @c_BT_Parm06  
       ,@Parm07 = @c_BT_Parm07  
       ,@Parm08 = @c_BT_Parm08  
       ,@Parm09 = @c_BT_Parm09  
       ,@Parm10 = @c_BT_Parm10  
  
       SET @d_Trace_Step1 = GETDATE()  
  
       SELECT @n_cnt = count(1) FROM  #Result  
  
       SET @c_counter = 100  
       IF @n_cnt <> 0  
  
       BEGIN  -- begin cnt  
       /*CS10 Start*/  
        DECLARE CUR_BartenderSPLoop CURSOR LOCAL FAST_FORWARD READ_ONLY  
        FOR  
       /*CS18 start*/  
       SELECT CONVERT(NVARCHAR(10),ID),  
              ISNULL(replace(col01,'"','""'),''),ISNULL(replace(col02,'"','""'),''),  
             ISNULL(replace(col03,'"','""'),''),ISNULL(replace(col04,'"','""'),''),  
              ISNULL(replace(col05,'"','""'),''),ISNULL(replace(col06,'"','""'),''),  
              ISNULL(replace(col07,'"','""'),''),ISNULL(replace(col08,'"','""'),''),  
              ISNULL(replace(col09,'"','""'),''),ISNULL(replace(col10,'"','""'),''),  
              ISNULL(replace(col11,'"','""'),''),ISNULL(replace(col12,'"','""'),''),  
              ISNULL(replace(col13,'"','""'),''),ISNULL(replace(col14,'"','""'),''),  
              ISNULL(replace(col15,'"','""'),''),ISNULL(replace(col16,'"','""'),''),  
              ISNULL(replace(col17,'"','""'),''),ISNULL(replace(col18,'"','""'),''),  
              ISNULL(replace(col19,'"','""'),''),ISNULL(replace(col20,'"','""'),''),  
              ISNULL(replace(col21,'"','""'),''),ISNULL(replace(col22,'"','""'),''),  
              ISNULL(replace(col23,'"','""'),''),ISNULL(replace(col24,'"','""'),''),  
              ISNULL(replace(col25,'"','""'),''),ISNULL(replace(col26,'"','""'),''),  
              ISNULL(replace(col27,'"','""'),''),ISNULL(replace(col28,'"','""'),''),  
              ISNULL(replace(col29,'"','""'),''),ISNULL(replace(col30,'"','""'),''),  
              ISNULL(replace(col31,'"','""'),''),ISNULL(replace(col32,'"','""'),''),  
              ISNULL(replace(col33,'"','""'),''),ISNULL(replace(col34,'"','""'),''),  
              ISNULL(replace(col35,'"','""'),''),ISNULL(replace(col36,'"','""'),''),  
              ISNULL(replace(col37,'"','""'),''),ISNULL(replace(col38,'"','""'),''),  
              ISNULL(replace(col39,'"','""'),''),ISNULL(replace(col40,'"','""'),''),  
              ISNULL(replace(col41,'"','""'),''),ISNULL(replace(col42,'"','""'),''),  
              ISNULL(replace(col43,'"','""'),''),ISNULL(replace(col44,'"','""'),''),  
              ISNULL(replace(col45,'"','""'),''),ISNULL(replace(col46,'"','""'),''),  
              ISNULL(replace(col47,'"','""'),''),ISNULL(replace(col48,'"','""'),''),  
              ISNULL(replace(col49,'"','""'),''),ISNULL(replace(col50,'"','""'),''),  
              ISNULL(replace(col51,'"','""'),''),ISNULL(replace(col52,'"','""'),''),  
              ISNULL(replace(col53,'"','""'),''),ISNULL(replace(col54,'"','""'),''),  
              ISNULL(replace(col55,'"','""'),''),ISNULL(replace(col56,'"','""'),''),  
              ISNULL(replace(col57,'"','""'),''),ISNULL(replace(col58,'"','""'),''),  
              ISNULL(replace(col59,'"','""'),''),ISNULL(replace(col60,'"','""'),'')  
              FROM   #Result  
              ORDER BY ID  
        /*CS18 End */  
        IF @b_debug='1'  
           BEGIN  
           SELECT 'Check'  
           SELECT * FROM #Result  
           END  
  
   OPEN CUR_BartenderSPLoop  
  
   FETCH NEXT FROM CUR_BartenderSPLoop  
   INTO @c_ID, @c_Col01, @c_Col02,@c_Col03,@c_Col04, @c_Col05,@c_Col06, @c_Col07,@c_Col08,@c_Col09,@c_Col10,  
           @c_Col11, @c_Col12,@c_Col13,@c_Col14, @c_Col15,@c_Col16, @c_Col17,@c_Col18,@c_Col19,@c_Col20,  
           @c_Col21, @c_Col22,@c_Col23,@c_Col24, @c_Col25,@c_Col26, @c_Col27,@c_Col28,@c_Col29,@c_Col30,  
           @c_Col31, @c_Col32,@c_Col33,@c_Col34, @c_Col35,@c_Col36, @c_Col37,@c_Col38,@c_Col39,@c_Col40,  
           @c_Col41, @c_Col42,@c_Col43,@c_Col44, @c_Col45,@c_Col46, @c_Col47,@c_Col48,@c_Col49,@c_Col50,  
           @c_Col51, @c_Col52,@c_Col53,@c_Col54, @c_Col55,@c_Col56, @c_Col57,@c_Col58,@c_Col59,@c_Col60  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
       SET @c_Fulltext = ''  
       SET @c_HeaderText = ''  
  
       SET @c_HeaderText = '"ID",'  
                         +'"Col01","Col02","Col03","Col04","Col05",'  
                         +'"Col06","Col07","Col08","Col09","Col10",'  
                         +'"Col11","Col12","Col13","Col14","Col15",'  
                         +'"Col16","Col17","Col18","Col19","Col20",'  
                         +'"Col21","Col22","Col23","Col24","Col25",'  
                         +'"Col26","Col27","Col28","Col29","Col30",'  
                         +'"Col31","Col32","Col33","Col34","Col35",'  
                         +'"Col36","Col37","Col38","Col39","Col40",'  
                         +'"Col41","Col42","Col43","Col44","Col45",'  
                         +'"Col46","Col47","Col48","Col49","Col50",'  
                         +'"Col51","Col52","Col53","Col54","Col55",'  
                         +'"Col56","Col57","Col58","Col59","Col60"'  
  
       SET @c_Fulltext = '"' + LTRIM(RTRIM(ISNULL(@c_ID,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col01,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col02,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col03,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col04,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col05,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col06,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col07,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col08,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col09,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col10,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col11,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col12,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col13,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col14,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col15,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col16,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col17,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col18,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col19,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col20,''))) + '"'  
                       +',"' + ISNULL(@c_col21,'') + '"'         --(CS13)  
                       +',"' + ISNULL(@c_col22,'') + '"'         --(CS13)  
                       +',"' + ISNULL(@c_col23,'') + '"'         --(CS13)  
                       +',"' + ISNULL(@c_col24,'') + '"'         --(CS13)  
                       +',"' + ISNULL(@c_col25,'') + '"'         --(CS13)  
                       +',"' + ISNULL(@c_col26,'') + '"'         --(CS13)  
                       +',"' + ISNULL(@c_col27,'') + '"'         --(CS13)  
                       +',"' + ISNULL(@c_col28,'') + '"'         --(CS13)  
                       +',"' + ISNULL(@c_col29,'') + '"'         --(CS13)  
                       +',"' + ISNULL(@c_col30,'') + '"'         --(CS13)  
           +',"' + ISNULL(@c_col31,'') + '"'  
                       +',"' + ISNULL(@c_col32,'') + '"'  
                       +',"' + ISNULL(@c_col33,'') + '"'  
                       +',"' + ISNULL(@c_col34,'') + '"'  
                       +',"' + ISNULL(@c_col35,'') + '"'  
                       +',"' + ISNULL(@c_col36,'') + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col37,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col38,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col39,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col40,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col41,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col42,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col43,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col44,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col45,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col46,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col47,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col48,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col49,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col50,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col51,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col52,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col53,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col54,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col55,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col56,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col57,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col58,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col59,''))) + '"'  
                       +',"' + LTRIM(RTRIM(ISNULL(@c_col60,''))) + '"'  
  
  
           SET @c_PrintJobName = ''  
  
           IF @b_debug='1'  
           BEGIN  
            PRINT ' counter ' + convert(nvarchar(10),@c_counter) + 'with ID : ' + convert(nvarchar(10),@n_CmdCounter)    --(CS19)  
            PRINT ' Full text : ' + @c_Fulltext  
            PRINT ' lenght 21 ' + RIGHT(@c_col21,20) + ' and lenght 22 : ' +  RIGHT(@c_col22,20)  
           END  
  
           IF ISNULL(@c_TemplatePath ,'') <> ''  
           BEGIN  
            SET @c_PrintJobName = ISNULL(RTRIM(@c_userid),'') + ISNULL(RTRIM(@c_Printername),'') + RTRIM(@c_LabelType) + convert(varchar(8),getdate(),112)+convert(varchar(10),getdate(),114) + case when @n_CntBarRec = 1 then convert(nvarchar(10),@c_ID) 
            Else convert(nvarchar(10),@n_CmdCounter) END --RTRIM(@c_ID)   --CS16  
  
              IF @b_Debug ='1'  
              BEGIN  
                 PRINT ' Print job name is :  ' + @c_Printername + ' with No of copy is : ' + @c_CopyPrint  
              END  
           END  
  
           SET @c_Filename = REPLACE(@c_PrintJobName,':','') + '.csv'  
  
           SET @c_BartenderCommand = '%BTW% /AF="' + @c_TemplatePath + '" /PRN="' + @c_Printername +  
               '" /PrintJobName="' + REPLACE(@c_PrintJobName,':','') + '" /R=3 /' + @c_CopyPrint + ' /P /D="%Trigger File Name%" '  
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand) + @c_NewLineChar +  '%END%'  
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand) + @c_NewLineChar +  @c_HeaderText  
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand) + @c_NewLineChar +  @c_Fulltext  
  
  
       IF @b_debug = '1'  
       BEGIN  
          Print 'String output : ' + @c_BartenderCommand  
       END  
  
      /* Send to Bartender - Start */  
      /*    EXECUTE nspg_GetKey  
      'TCPOUTLog',  
      9,  
      @c_MessageNum_Out OUTPUT,  
      @b_Success OUTPUT,  
      @n_Err OUTPUT,  
      @c_ErrMsg OUTPUT  
  
      IF @b_Success = 1      */  
    -- BEGIN  
         SET @c_DPC_MessageNo = 'C' + '000000000' --+ @c_MessageNum_Out  
     -- END  
  
      SET @n_Trace_NoOfLabel = @n_Trace_NoOfLabel + 1  
  
      IF ISNULL(@c_BartenderCommand,'') <> ''  
      BEGIN  
  
      IF @b_debug = '1'  
      BEGIN  
       SELECT ' result ' + @c_BartenderCommand  
      END  
  
      INSERT INTO TCPSocket_OUTLog  
        (  
          MessageNum   ,MessageType ,[Application]  
         ,DATA         ,STATUS      ,StorerKey  
         ,LabelNo      ,BatchNo     ,RemoteEndPoint  
        )  
      VALUES  
        (  
          @c_DPC_MessageNo  
         ,'SEND'  
         ,'BARTENDER'  
         ,@c_BartenderCommand  
         ,'0'  
         ,@c_Storerkey                   --(CS17)  
         ,''  
         ,''  
         ,@c_RemoteEndPoint  
        )  
       END  
       SET @n_SerialNo_Out = @@IDENTITY  
  
      IF @b_Debug = '1'  
      BEGIN  
         SELECT @n_SerialNo_Out '@n_SerialNo_Out'  
         PRINT @c_RemoteEndPoint  
      END  
  
--      SELECT @n_SerialNo_Out = SerialNo  
--      FROM   dbo.TCPSocket_OUTLog WITH (NOLOCK)  
--      WHERE  MessageNum = @c_DPC_MessageNo  
--      AND    MessageType = 'SEND'  
--      AND    STATUS = '0'  
  
      SET @c_vbErrMsg = ''  
      SET @c_ReceiveMessage = ''  
  
      EXEC [master].[dbo].[isp_GenericTCPSocketClient]  
           @c_IniFilePath  
          ,@c_RemoteEndPoint  
          ,@c_BartenderCommand  
          ,@c_LocalEndPoint OUTPUT  
          ,@c_ReceiveMessage OUTPUT  
          ,@c_vbErrMsg OUTPUT  
  
      /* SELECT @c_BartenderCommand '@c_BartenderCommand'  
            ,@c_LocalEndPoint '@c_LocalEndPoint'  
            ,@c_ReceiveMessage '@c_ReceiveMessage'  
            ,@c_vbErrMsg '@c_vbErrMsg'             */  
  
      IF ISNULL(RTRIM(@c_vbErrMsg) ,'') <> ''  
      BEGIN  
          SET @n_Status_Out = 5  
  
          UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)  
          SET    STATUS = CONVERT(VARCHAR(1) ,@n_Status_Out)  
                ,ErrMsg = ISNULL(@c_ReceiveMessage ,'')  
                ,LocalEndPoint = @c_LocalEndPoint  
          WHERE  SerialNo = @n_SerialNo_Out  
  
          SET @b_Success = 0  
          SET @n_Err = 80453  
          SET @c_ErrMsg = @c_vbErrMsg  
      END  
  
      IF ISNULL(RTRIM(@c_ReceiveMessage) ,'') <> ''  
      BEGIN  
          SET @n_Status_Out = 9  
  
          UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)  
          SET    STATUS         = CONVERT(VARCHAR(1) ,@n_Status_Out)  
                ,ErrMsg         = ISNULL(@c_ReceiveMessage ,'')  
                ,LocalEndPoint  = @c_LocalEndPoint  
          WHERE  SerialNo       = @n_SerialNo_Out  
      END  
  
      IF @b_Debug = '1'  
      BEGIN  
         PRINT convert(nvarchar(20),getdate(),120)  
      END  
  
      IF @b_Debug = '1'  
      BEGIN  
          PRINT 'Err return ' + @c_result  
      END  
  
      IF @c_Returnresult = 'Y'  
      BEGIN  
          IF ISNULL(@c_result ,'') = ''  
          BEGIN  
              SET @n_err=0  
              SET @c_result = 'No Error'  
              SET @c_errmsg = 'No Error'  
              SELECT @n_err,@c_result,@c_errmsg AS c_Result  
          END  
      END  
  
    WHILE @@TRANCOUNT > 0  
    COMMIT TRAN  
  
   SET @c_counter = @c_counter + 1  
   FETCH NEXT FROM CUR_BartenderSPLoop  
   INTO @c_ID, @c_Col01, @c_Col02,@c_Col03,@c_Col04, @c_Col05,@c_Col06, @c_Col07,@c_Col08,@c_Col09,@c_Col10,  
           @c_Col11, @c_Col12,@c_Col13,@c_Col14, @c_Col15,@c_Col16, @c_Col17,@c_Col18,@c_Col19,@c_Col20,  
           @c_Col21, @c_Col22,@c_Col23,@c_Col24, @c_Col25,@c_Col26, @c_Col27,@c_Col28,@c_Col29,@c_Col30,  
           @c_Col31, @c_Col32,@c_Col33,@c_Col34, @c_Col35,@c_Col36, @c_Col37,@c_Col38,@c_Col39,@c_Col40,  
           @c_Col41, @c_Col42,@c_Col43,@c_Col44, @c_Col45,@c_Col46, @c_Col47,@c_Col48,@c_Col49,@c_Col50,  
           @c_Col51, @c_Col52,@c_Col53,@c_Col54, @c_Col55,@c_Col56, @c_Col57,@c_Col58,@c_Col59,@c_Col60  
     END  
  
     CLOSE CUR_BartenderSPLoop  
     DEALLOCATE CUR_BartenderSPLoop  
   /*CS10 END*/  
  
    END --end cnt=0  
    ELSE  
    BEGIN  
      IF @c_Returnresult = 'Y'  
      BEGIN  
          IF ISNULL(@c_result ,'') = ''  
          BEGIN  
            SELECT @n_err = 25001  
            SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': No Record for label type  : ' + @c_LabelType + ' (ispRdtBartenderCmd) '  
            SET @c_result = @c_errmsg  
            SELECT (convert(nvarchar(5),@n_err) + @c_result + @c_errmsg) AS c_Result --(CS14)  
          END  
      END  
      ELSE  
      /*CS11 Start*/  
      BEGIN  
          IF @n_IsRDT <> 1  --CS15  
             BEGIN  
                IF ISNULL(@c_result ,'') = ''  
                BEGIN  
                  SELECT @n_err = 25002  
                  SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': No Record for label type  : ' + @c_LabelType + ' (ispRdtBartenderCmd) '  
                  SET @c_result = @c_errmsg  
                  SELECT @n_err,@c_result,@c_errmsg AS c_Result  
                END  
  
             END  
      END  
      /*CS11 END*/  
    END  
      -- Purposely wait for 1 second  
  
--      WHILE @@TRANCOUNT > 0  
--      COMMIT TRAN  
  
   -- WAITFOR DELAY '00:00:01'     --CS09  
  
   FETCH NEXT FROM CUR_BartenderCommandLoop  
   INTO @n_CmdCounter,@c_BT_Parm01, @c_BT_Parm02, @c_BT_Parm03,  
           @c_BT_Parm04, @c_BT_Parm05, @c_BT_Parm06,  
           @c_BT_Parm07, @c_BT_Parm08, @c_BT_Parm09,  
           @c_BT_Parm10, @c_KEY01, @c_KEY02,  
           @c_KEY03, @c_KEY04, @c_KEY05  
  
   END  
  
    IF @c_Returnresult = 'Y'  
      BEGIN  
          IF ISNULL(@c_result ,'') = ''  
          BEGIN  
            SELECT @n_err = 25003  
            SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': No Record for label type  : ' + @c_LabelType + ' (ispRdtBartenderCmd) '  
            SET @c_result = @c_errmsg  
            SELECT (convert(nvarchar(5),@n_err) + @c_result + @c_errmsg) AS c_Result --(CS14)  
          END  
      END  
    -- ELSE  
    /*CS11 Start*/  
     -- BEGIN  
         -- IF @n_IsRDT <> 1  
--          BEGIN  
       --      PRINT @c_result  
       --      IF ISNULL(@c_result ,'') = ''  
--             BEGIN  
--             SELECT @n_err = 25004  
--             SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': No Record for label type  : ' + @c_LabelType + ' (ispRdtBartenderCmd) '  
--             SET @c_result = @c_errmsg  
--             END  
--          END  
--          ELSE  
     --     BEGIN  
      --    SET @n_err = 25005  
      --    SET @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': No Record for label type  : ' + @c_LabelType + ' (ispRdtBartenderCmd) '  
       --   END  
  
         /*CS11 END*/  
  
  --   END  
  
    IF @n_err <> 0  
  
      BEGIN  
  
                SET @c_DPC_MessageNo = 'C' + '000000000' --+ @c_MessageNum_Out  
                --SET @n_err = 25000  
                --SET @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': No Record for label type  : ' + @c_LabelType + ' (ispRdtBartenderCmd) '  
                SET @c_result = @c_errmsg  
                --  SET @c_result = 'Error Code : ' + +  
--                SET @c_OutLog = 'Parameter01 : ' + @c_BT_Parm01 + 'Parameter02 : ' + @c_BT_Parm02 + 'Parameter03 : ' + @c_BT_Parm03 + 'Parameter04 : ' + @c_BT_Parm04 + 'Parameter05 : ' + @c_BT_Parm05 +  
--                                'Parameter06 : ' + @c_BT_Parm06 + 'Parameter07 : ' + @c_BT_Parm07 + 'Parameter08 : ' + @c_BT_Parm08 + 'Parameter09 : ' + @c_BT_Parm09 + 'Parameter10 : ' + @c_BT_Parm10  
  
                INSERT INTO TCPSocket_OUTLog  
                 (  
                   MessageNum   ,MessageType ,[Application]  
                  ,DATA         ,STATUS      ,StorerKey  
             ,LabelNo      ,BatchNo     ,RemoteEndPoint,ErrMsg  
                 )  
               VALUES  
                 (  
                   @c_DPC_MessageNo  
                  ,'SEND'  
                  ,'BARTENDER'  
                  ,@cSQL  
                  ,'5'  
                  ,@c_Storerkey  
                  ,''  
                  ,''  
                  ,@c_RemoteEndPoint  
                  ,@c_result  
                 )  
  
                END  -- End log into TCP_LOG for RDT  
  
--       SET @n_StartTrnCnt = @@TRANCOUNT  
--  
--       WHILE @@TRANCOUNT > 0  
--       COMMIT TRAN  
  
   CLOSE CUR_BartenderCommandLoop  
   DEALLOCATE CUR_BartenderCommandLoop  
  
  
  
   SET @c_Trace_Step1 = ISNULL(@c_userid, SUSER_SNAME() ) -- CONVERT(VARCHAR(12),GETDATE() - @d_Trace_Step1 ,114)  
   SET @c_Trace_Step2 = ISNULL(CAST(@n_Trace_NoOfLabel AS VARCHAR(10)), '')  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
  
   EXEC isp_InsertTraceInfo  
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'ispRdtBartenderCmd',  
      @c_starttime = @d_Trace_StartTime,  
      @c_endtime = @d_Trace_EndTime,  
      @c_step1 = @c_Trace_Step1,  
      @c_step2 = @c_Trace_Step2,  
      @c_step3 = '',  
      @c_step4 = '',  
      @c_step5 = '',  
      @c_col1 = @c_userid,  
      @c_col2 = @c_Parm01,  
      @c_col3 = @c_Parm02,  
      @c_col4 = @c_Parm03,  
      @c_col5 = @c_Parm04,  
      @b_Success = 1,  
      @n_Err = 0,  
      @c_ErrMsg = ''  
  
  
QUIT:  
  
 WHILE @@TRANCOUNT < @n_StartTrnCnt  
 BEGIN TRAN  
  
END

GO