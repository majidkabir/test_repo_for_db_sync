SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/        
/* Copyright: Maersk                                                           */        
/* Purpose: For BarTender Generic Store Procedure                              */        
/*                                                                             */        
/* Modifications log:                                                          */        
/*                                                                             */        
/* Date       Rev  Author     Purposes                                         */        
/* 2013-06-28 1.0  CSCHONG    Created                                          */        
/* 2013-09-11 2.0  CSCHONG    Add in error msg and number return (CS01)        */        
/* 2013-09-23 3.0  CSCHONG    Add in new parameter for no of copy (CS02)       */        
/* 2013-10-01 4.0  CSCHONG    Add in StorerKey in label config table (CS03)    */        
/* 2013-10-07 5.0  CSCHONG    Add in c_Returnresult parameter  (CS04)          */        
/* 2013-10-09 6.0  CSCHONG    PrinterName:WinPrinter 1st delimiter value(CS05) */        
/* 2013-10-10 7.0  CSCHONG    Default userid to SUSER_SNAME() if NULL (CS06)   */        
/* 2013-11-07 8.0  CSCHONG    For RDT get printer from rdtmobile  (CS07)       */        
/* 2013-11-19 9.0  CSCHONG    Create text file send by TCP IP  (CS08)          */        
/* 2013-11-29 10.0 CSCHONG    Remove wait for delay 1 sec to increase print    */        
/*                            performance   (CS09)                             */        
/* 2013-12-05 11.0 CSCHONG    create cursor to loop sub SP (CS10)              */        
/* 2014-01-28 12.0 CSCHONG    Cater for PB RCM retrun no record error (CS11)   */        
/* 2014-02-11 13.0 CSCHONG    Increase lenght noofcopy to 5 (CS12)             */        
/* 2014-04-11 14.0 CSCHONG    Remove LTRIM for SOS298740 (CS13)                */        
/* 2014-05-14 15.0 CSCHONG    FIX PB view report error (CS14)                  */        
/* 2014-05-27 15.1 CSCHONG    FIX RDT return error (C15)                       */        
/* 2014-07-17 16.0 CSCHONG    Add counter in printername (CS16)                */        
/* 2014-08-01 17.0 CSCHONG    Add StorerKey in OUTLOG (CS17)                   */        
/* 2014-09-10 18.0 CSCHONG    Fix double code  delimeter bugs (CS18)           */        
/* 2014-10-14 19.0 CSCHONG    increase counter lenght to 10 (CS19)             */        
/* 2015-07-01 20.0 CSCHONG    Add loadkey and orderkey and retry for           */        
/*                            tcpsocket_outlog error (CS20)                    */        
/* 2015-07-06 20.1 CSCHONG    Print by batch (CS21)                            */        
/* 2015-07-23 20.2 CSCHONG    log max 20 char for Refno field  in              */        
/*                             tcpsocket_outlog table (CS22)                   */        
/* 2015-07-29 20.3 CSCHONG    Add check len for commander scripts              */        
/*                            for Max 4000 character (CS23)                    */        
/* 2015-08-06 20.4 CSCHONG    Add in start and end count in table filter(CS24) */        
/* 2015-08-27 20.1 CSCHONG    Add in log print log to table (CS25)             */        
/* 2015-09-08 20.2 CSCHONG    add in track start time in log (CS26)            */        
/* 2015-09-30 20.3 CSCHONG    Fix bugs for multiple shipperkey in 1 load(CS27) */        
/* 2015-10-20 20.4 CSCHONG    Fix RDT cannot print label and sequence issue    */        
/*                            For qty=1 (CS28)                                 */        
/* 2015-11-06 20.5 CSCHONG    Fix for shipperkey more than 7 (CS29)            */        
/* 2015-11-25 20.6 CSCHONG    Fix max record per job for StorerKey 18496       */        
/*                            for duplicate issue (CS30)                       */        
/* 2016-09-09 20.7 CSCHONG    Fix recompile issue (CS30a)                      */      
/* 2016-07-04 20.8 CSCHONG    IN00086992 - Qty Printing Issue                  */     
/* 2016-11-10 20.8 CSCHONG    Fix HM mising orderkey print out (CS30b)         */        
/* 2016-12-02 20.9 CSCHONG    Restructure scripts for non batch job (CS31)     */        
/* 2016-12-27 21.0 CSCHONG    Fix the lenght to >= 4000 (CS32)                 */        
/* 2017-01-16 21.1 CSCHONG    Fix batch 2 last record print issue (CS32a)      */        
/* 2017-01-09 21.2 CSCHONG    Restructure scripts for batch job printing (CS33)*/        
/* 2017-01-18 21.3 CSCHONG    cater for diffrence printer by btw file (CS34)   */        
/* 2017-02-16 21.4 CSCHONG    Fix duplicate label print out (CS34a)            */        
/* 2017-09-14 21.5 CSCHONG    Add traceinfo (CS35)                             */        
/* 2017-06-23 21.6 CSCHONG    Filter by StorerKey (CS38)                       */        
/* 2017-09-21 21.7 CSCHONG    Remarks CS37 for begin CATCH (CS39)              */        
/* 2017-10-02 21.8 CSCHONG    Reduce use #temp table for single record (CS36)  */        
/* 2017-10-13 21.9 SHONG      Submit to Q-Commander be default                 */        
/* 2017-12-18 22.0 CheeMun    INC0069041 - Delete #Result temp table record    */        
/* 2018-08-19 21.9 LEONG      Revise error message (L01).                      */        
/* 2018-09-18 23.0 CSCHONG    Add sorting (CS_sort_fix)                        */        
/* 2018-10-30 23.1 SHONG      Use Printer ID as TransmitlogKey                 */        
/* 2019-02-22 23.2 CSCHONG    WMS-4692-remove is rdt GOTO QUIT (CS40)          */        
/* 2020-02-25 23.3 CSCHONG    set QCmdSubmitFlag default value to blank (CS41) */        
/* 2020-01-20 23.3 CSCHONG    support qcommander print ZPL (CS42)              */       
/* 2020-04-04 23.4 CSCHONG    update qcommander cmdtype logic (CS43)           */   
/* 2020-07-29 23.4 CSCHONG    support multi shipperkey print ZPL (CS43a)       */    
/* 2021-12-20 23.5 CSCHONG    Devops Scripts Combine and increase username     */
/*                            field length to NVARCHAR(256) (CS44)             */
/* 2023-04-04 23.6 Wan01      WMS-22125 - Backend Bartender DB-MQ              */
/* 2023-10-23 23.7 Wan02      Get Print Over Internet Printing                 */
/* 2023-12-19 24.8 Wan        UWP-12373-MWMS Deploy MasterSP to V2             */
/* 2024-07-26 24.9 JackC      UWP-26905 Encrypt user password                  */
/* 2024-09-11 25.0 NLT013     UWP-24328 Extended the length for @c_Param0      */
/*******************************************************************************/        
--> For CN Only: @cCmdType = 'PRN'        
CREATE   PROC [dbo].[isp_BT_GenBartenderCommand](        
      @cPrinterID          NVARCHAR(50)        
     ,@c_LabelType         NVARCHAR(30)        
     ,@c_userid            NVARCHAR(256)           --CS44   
     ,@c_Parm01            NVARCHAR(80)        
     ,@c_Parm02            NVARCHAR(80)        
     ,@c_Parm03            NVARCHAR(80)        
     ,@c_Parm04            NVARCHAR(80)        
     ,@c_Parm05            NVARCHAR(80)        
     ,@c_Parm06            NVARCHAR(80)        
     ,@c_Parm07            NVARCHAR(80)        
     ,@c_Parm08            NVARCHAR(80)        
     ,@c_Parm09            NVARCHAR(80)        
     ,@c_Parm10            NVARCHAR(80)        
     ,@c_StorerKey         NVARCHAR(15) =''            --CS03        
     ,@c_NoCopy            CHAR(5)                     --CS02 --CS12        
     ,@b_Debug             CHAR(1)=0       
     ,@c_Returnresult      NCHAR(1)='N'                --CS04        
     ,@n_err               INT = 0             OUTPUT  --CS01        
     ,@c_errmsg            NVARCHAR(250)=''    OUTPUT  --CS01        
     ,@c_StartRec          NVARCHAR(5) = ''            --(CS24)        
     ,@c_EndRec            NVARCHAR(5) =''             --(CS24)        
     ,@c_FromSourceModule  NVARCHAR(250) = ''        
     ,@c_QCmdSubmitFlag    CHAR(1) = ''
     ,@n_JobID             BIGINT  = 0                                              --(Wan01) 
  )        
AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE @c_APP_DB_Name        NVARCHAR(20)  = ''        
      , @c_DataStream            VARCHAR(10)   = ''        
      , @n_ThreadPerAcct         INT           = 0        
      , @n_ThreadPerStream       INT           = 0        
      , @n_MilisecondDelay       INT           = 0        
      , @c_IP                    NVARCHAR(20)  = ''        
      , @c_PORT                  NVARCHAR(5)   = ''        
      , @c_CmdType               NVARCHAR(10)  = ''        
      , @c_TaskType              NVARCHAR(1)   = ''        
      , @cCommand                NVARCHAR(4000) = ''        
        
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
          ,@c_GetUserID     NVARCHAR(256)    --CS06  --CS44      
          ,@n_CntUser       INT               --CS06        
          ,@n_StartTrnCnt   INT        
          ,@c_counter       INT        
          ,@n_CmdCounter    INT              --CS16        
          ,@n_PrnCounter    INT              --CS16        
          ,@n_CntBarRec     INT              --CS16        
          ,@c_Retrieve      NVARCHAR(2)      --(CS23)        
          ,@c_LastRec       NVARCHAR(2)      --(CS23)        
          ,@c_LogFile       NVARCHAR(1)      --(CS25)        
          ,@c_Field01       NVARCHAR(80)    --(CS25)        
          ,@c_Field02       NVARCHAR(80)    --(CS25)        
          ,@c_Field03       NVARCHAR(80)    --(CS25)        
          ,@c_GetField01    NVARCHAR(80)    --(CS25)        
          ,@c_GetField02    NVARCHAR(80)    --(CS25)        
          ,@c_GetField03    NVARCHAR(80)    --(CS25)        
          ,@n_CntPrnLogTBL  INT             --(CS28)        
          ,@c_BTPrinterID   NVARCHAR(10)    --(CS34)        
          ,@c_TCPstatus     NVARCHAR(10)    --(CS36)        
          ,@c_FilePath      NVARCHAR(1000)  --(CS42)        
          ,@c_ZPLPrint      NVARCHAR(5)     --(CS42)        
          ,@c_zplprn        NVARCHAR(1)='N' --(CS43)    
          ,@c_condition     NVARCHAR(250) = '' --(CS43)    
          ,@c_qcmdtype      NVARCHAR(20) = 'SQL' --(CS43)    
          ,@c_SQLJOIN        NVARCHAR(MAX)   --(CS43)    
          ,@c_ZPLPrinterName NVARCHAR(150)=''   --(CS43) 
                 
          ,@n_PrintOverInternet  INT         = 0   --(Wan01) 
          ,@n_POS                INT         = 0   --(Wan01)
          ,@c_JobType            NVARCHAR(10)= ''  --(Wan01)                           
          ,@c_BatchNo            NVARCHAR(30)= ''  --(Wan01)  
   
   DECLARE @t_PrintJob           TABLE             --(Wan01)
          ( JobType              NVARCHAR(10)   NOT NULL DEFAULT(''))                                                               
        
   SET @n_StartTrnCnt = @@TRANCOUNT        
        
   DECLARE @c_BartenderCommand  NVARCHAR(MAX)        
          ,@c_BartenderHCommand NVARCHAR(MAX)        
          ,@c_BartenderFCommand NVARCHAR(MAX)        
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
          ,@c_BT_Parm01         NVARCHAR(80)        
          ,@c_BT_Parm02         NVARCHAR(80)        
          ,@c_BT_Parm03         NVARCHAR(80)        
          ,@c_BT_Parm04         NVARCHAR(80)        
          ,@c_BT_Parm05         NVARCHAR(80)        
          ,@c_BT_Parm06         NVARCHAR(80)        
          ,@c_BT_Parm07         NVARCHAR(80)        
          ,@c_BT_Parm08         NVARCHAR(80)        
          ,@c_BT_Parm09         NVARCHAR(80)        
          ,@c_BT_Parm10         NVARCHAR(80)        
          ,@c_tempfilepath      NVARCHAR(215)   --CS08        
          ,@c_FullText          NVARCHAR(MAX)   --CS08        
          ,@c_HeaderText        NVARCHAR(MAX)   --CS08        
          ,@c_Filename          NVARCHAR(100)   --CS08        
          ,@n_WorkFolderExists  INT             --CS08        
          ,@c_WorkFilePath      NVARCHAR(215)   --CS08        
          ,@c_SqlString         NVARCHAR(MAX)  --CS08        
          ,@c_NewLineChar       CHAR(2)         --CS08        
          ,@c_GetFullText       NVARCHAR(MAX)  --CS08        
          ,@c_SubFullText       NVARCHAR(MAX)  --CS23        
          ,@c_RemainText        NVARCHAR(MAX)  --CS23        
          ,@n_cnt               INT        
          ,@n_cntbartender      INT        
          ,@c_OutLog            NVARCHAR(4000) --CS11        
          ,@n_Retry             INT            --(CS20)        
          ,@n_MaxTry            INT            --(CS20)        
          ,@n_StartCnt          INT            --(CS21)        
          ,@n_CntPBatch         INT            --(CS21)        
          ,@n_TTLREC            INT            --(CS21)        
          ,@c_StopBatch         NVARCHAR(1)    --(CS21)        
          ,@n_Batch             INT        
          ,@n_CNTBatchRec       INT        
          ,@n_CommandLength     INT            --(CS23)        
          ,@n_TextLength        INT            --(CS23)        
          ,@n_TextMaxLength     INT            --(CS23)        
          ,@c_ExceedMaxLength   NCHAR(1)       --(CS23)        
          ,@n_CNTBatch          INT            --(CS28)        
          ,@c_BARTENDERQCMDFLAG NVARCHAR(1) = '0'    --(CS41)  
          ,@c_shipperkey        NVARCHAR(80)    --(CS43a)        
        
   DECLARE @d_Trace_StartTime  DATETIME,        
            @d_Trace_EndTime    DATETIME,        
            @n_Trace_NoOfLabel  INT,        
            @d_Trace_Step1      DATETIME,        
            @c_Trace_Step1      NVARCHAR(20),        
            @c_Trace_Step2      NVARCHAR(20),        
            @c_UserName         NVARCHAR(256),          --CS44        
            @c_ExecStatements   NVARCHAR(MAX),        
            @c_ExecArguments    NVARCHAR(MAX)        
        
   SET @d_Trace_StartTime = GETDATE()        
        
   DECLARE @c_ID     NVARCHAR (80),        
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
        
 /*CS27 Start*/        
   DECLARE @c_LKEY01             NVARCHAR(60)        
          ,@c_LKEY02             NVARCHAR(60)        
          ,@c_LKEY03             NVARCHAR(60)        
          ,@c_LKEY04             NVARCHAR(60)        
          ,@c_LKEY05             NVARCHAR(60)        
          ,@n_LCmdCounter        INT        
          ,@c_BT_LParm01         NVARCHAR(80)        
          ,@c_BT_LParm02         NVARCHAR(80)        
          ,@c_BT_LParm03         NVARCHAR(80)        
          ,@c_BT_LParm04         NVARCHAR(80)        
          ,@c_BT_LParm05         NVARCHAR(80)        
          ,@c_BT_LParm06         NVARCHAR(80)        
          ,@c_BT_LParm07         NVARCHAR(80)        
          ,@c_BT_LParm08         NVARCHAR(80)        
          ,@c_BT_LParm09         NVARCHAR(80)        
          ,@c_BT_LParm10         NVARCHAR(80)        
          ,@c_GetKey05           NVARCHAR(60)        
          ,@n_BatchCnt           INT        
          ,@c_GetRecNo           NVARCHAR(80)        
          ,@cTransmitlogKey      NVARCHAR(10)        
   /*CS27 End*/        
        
   /*CS35 start*/        
        
    DECLARE   @d_starttime    datetime,        
              @d_endtime      datetime,        
              @d_step1        datetime,        
              @d_step2        datetime,        
              @d_step3        datetime,        
              @d_step4        datetime,        
              @d_step5        datetime,        
              @c_col1         NVARCHAR(20),        
              @c_col2         NVARCHAR(20),        
              @c_col3         NVARCHAR(20),        
              @c_col4         NVARCHAR(20),        
              @c_col5         NVARCHAR(20),        
              @c_TraceName    NVARCHAR(80)        
        
   /*CS35 End*/        
   /*CS41 START*/        
   IF EXISTS (SELECT 1 FROM QCmd_TransmitlogConfig WITH (NOLOCK)        
            WHERE TableName  = 'BartenderQCmd'        
            AND   [App_Name] = 'WMS'        
            AND   (StorerKey  = 'ALL'  OR Storerkey = @c_StorerKey) )        
   BEGIN        
      IF @c_QCmdSubmitFlag = ''        
      BEGIN        
         SET @c_QCmdSubmitFlag = '1'        
      END        
   END        
   ELSE        
   BEGIN        
      IF @c_QCmdSubmitFlag = '1'        
      BEGIN        
         SET @c_QCmdSubmitFlag = '0'        
      END        
   END        
        
   --GOTO QUIT        
        
  /*CS41 END*/        
   IF @c_QCmdSubmitFlag = '1' AND @c_Returnresult <> 'Y'        
   BEGIN        
      SELECT @c_APP_DB_Name      = APP_DB_Name        
        , @c_DataStream          = DataStream        
        , @n_ThreadPerAcct       = ThreadPerAcct        
        , @n_ThreadPerStream     = ThreadPerStream        
        , @n_MilisecondDelay     = MilisecondDelay        
        , @c_IP                  = IP        
        , @c_PORT                = PORT        
        , @c_IniFilePath         = IniFilePath        
        , @c_CmdType             = CmdType        
        , @c_TaskType            = TaskType        
      FROM  QCmd_TransmitlogConfig WITH (NOLOCK)        
      WHERE TableName  = 'BartenderQCmd'        
      AND   [App_Name] = 'WMS'        
      AND   (StorerKey  = 'ALL' OR Storerkey = @c_StorerKey)       --CS41        
        
      IF @c_IP = ''        
      BEGIN        
         SET @n_Err = 60205        
         SET @c_ErrMsg = 'Q-Commander TCP Socket not setup!'        
         RETURN        
      END        
        
      SET @cCommand = N'EXEC [dbo].[isp_BT_GenBartenderCommand] ' +        
                    N' @cPrinterID = ' + QUOTENAME(ISNULL(@cPrinterID,''), '''') +        
                    N',@c_LabelType = ' + QUOTENAME(ISNULL(@c_LabelType,''), '''') +        
                    N',@c_userid = ' + QUOTENAME(ISNULL(@c_userid,''), '''') +        
                    N',@c_Parm01 = ' + QUOTENAME(ISNULL(@c_Parm01,''), '''') +        
                    N',@c_Parm02 = ' + QUOTENAME(ISNULL(@c_Parm02,''), '''') +        
                    N',@c_Parm03 = ' + QUOTENAME(ISNULL(@c_Parm03,''), '''') +        
                    N',@c_Parm04 = ' + QUOTENAME(ISNULL(@c_Parm04,''), '''') +        
                    N',@c_Parm05 = ' + QUOTENAME(ISNULL(@c_Parm05,''), '''') +        
                    N',@c_Parm06 = ' + QUOTENAME(ISNULL(@c_Parm06,''), '''') +        
                    N',@c_Parm07 = ' + QUOTENAME(ISNULL(@c_Parm07,''), '''') +        
                    N',@c_Parm08 = ' + QUOTENAME(ISNULL(@c_Parm08,''), '''') +        
                    N',@c_Parm09 = ' + QUOTENAME(ISNULL(@c_Parm09,''), '''') +        
                    N',@c_Parm10 = ' + QUOTENAME(ISNULL(@c_Parm10,''), '''') +        
                    N',@c_StorerKey = ' + QUOTENAME(ISNULL(@c_StorerKey,''), '''') +        
                    N',@c_NoCopy = ' + QUOTENAME(ISNULL(@c_NoCopy,''), '''') +        
                    N',@b_Debug = ' + QUOTENAME(ISNULL(@b_Debug,''), '''') +        
                    N',@c_Returnresult = ' + QUOTENAME(ISNULL(@c_Returnresult,''), '''') +        
                    N',@n_err = ' + '0' +        
                    N',@c_errmsg = ' + QUOTENAME(ISNULL(@c_errmsg,''), '''') +        
                    N',@c_StartRec = ' + QUOTENAME(ISNULL(@c_StartRec,''), '''') +        
                    N',@c_EndRec= ' + QUOTENAME(ISNULL(@c_EndRec,''), '''') +        
                    N',@c_FromSourceModule = ' + QUOTENAME('isp_BT_GenBartenderCommand','''') +        
                    N',@c_QCmdSubmitFlag  = ' + QUOTENAME('0','''')  +
                    N',@n_JobID = ' + CONVERT(NVARCHAR(10), @n_JobID)               --(Wan02)     
    
      --(CS43) START    
  
      SET @c_shipperkey = ''  
  
      IF @c_labeltype ='CTNMARKLBL'  
      BEGIN  
         SELECT TOP 1 @c_shipperkey = OH.ShipperKey  
         FROM PACKHEADER PH WITH (NOLOCK)     
         JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickslipNo)    
         JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)    
         WHERE PH.Pickslipno = @c_Parm01 AND PD.CartonNo >= CONVERT(INT,@c_Parm02) AND PD.CartonNo <= CONVERT(INT,@c_Parm03)   
      END  
    
      SELECT @c_condition = C.long    
      FROM CODELKUP C WITH (NOLOCK)    
      WHERE C.listname = 'BTZPLPRN'    
      AND C.short = 'CONDITION'    
      AND C.storerkey = @c_StorerKey     
      AND C.notes = @c_labeltype    
    
    --select @c_condition '@c_condition'    
    
      SET @c_SQLJOIN ='SELECT TOP 1 @c_zplprn=bt.zplprinting ' +    
                     ' FROM BartenderLabelCfg BT WITH (NOLOCK) ' +    
                     ' JOIN CODELKUP c WITH (NOLOCK) ON c.listname= ''BTZPLPRN'' ' +     
                     ' AND c.storerkey = BT.storerkey AND c.long=BT.labeltype ' +    
                     ' AND c.short=bt.zplprinting AND c.udf01=BT.key01 ' +     
                     ' AND c.udf02=BT.key02 AND c.udf03=BT.key03 ' +    
                     ' AND c.udf04=BT.key04 AND c.udf05=BT.key05 '+      
                     ' WHERE c.long = @c_labeltype '     
                               
      SET @cSQL = @c_SQLJOIN  + @c_condition    
        
      SET @c_ExecArguments = N'@c_Parm01           NVARCHAR(80),' +    
                              '@c_Parm02           NVARCHAR(80),' +     
                              '@c_Parm03           NVARCHAR(80),' +     
                              '@c_Parm04           NVARCHAR(80),' +     
                              '@c_Parm05           NVARCHAR(80),' +     
                              '@c_Parm06           NVARCHAR(80),' +     
                              '@c_Parm07           NVARCHAR(80),' +     
                              '@c_Parm08           NVARCHAR(80),' +     
                              '@c_Parm09           NVARCHAR(80),' +     
                              '@c_Parm10           NVARCHAR(80),' +     
                              '@c_labeltype        NVARCHAR(30),' +     
                              '@c_shipperkey       NVARCHAR(80),' +    
                              '@c_zplprn           NVARCHAR(80) OUTPUT'      
                        
      EXEC sp_ExecuteSql     @cSQL         
                           , @c_ExecArguments        
                           , @c_Parm01        
                           , @c_Parm02    
                           , @c_Parm03    
                           , @c_Parm04    
                           , @c_Parm05    
                           , @c_Parm06    
                           , @c_Parm07    
                           , @c_Parm08    
                           , @c_Parm09    
                           , @c_Parm10    
                           , @c_labeltype   
                           , @c_shipperkey   
                           , @c_zplprn  OUTPUT    
  
      IF @c_zplprn = '1'    
      BEGIN    
         SET @c_qcmdtype = 'PRN'    
      END    
    
  --select @c_qcmdtype '@c_qcmdtype'    
  --GOTO QUIT    
    
   --(CS43) END    
      BEGIN TRY        
         SET @cTransmitlogKey = LEFT(@cPrinterID, 10)        
        
         EXEC isp_QCmd_SubmitTaskToQCommander        
                 @cTaskType         = 'O' -- D=By Datastream, T=Transmitlog, O=Others        
               , @cStorerKey        = @c_StorerKey        
               , @cDataStream       = 'BARTENDER'        
              -- , @cCmdType          = 'SQL'        
               --, @cCmdType          = 'PRN'                            --CS42        
               , @cCmdType          = @c_qcmdtype                         --CS43        
               , @cCommand          = @cCommand        
               , @cTransmitlogKey   = @cTransmitlogKey        
               , @nThreadPerAcct    = @n_ThreadPerAcct        
               , @nThreadPerStream  = @n_ThreadPerStream        
               , @nMilisecondDelay  = @n_MilisecondDelay        
               , @nSeq              = 1        
               , @cIP               = @c_IP        
               , @cPORT             = @c_PORT        
               , @cIniFilePath      = @c_IniFilePath        
               , @cAPPDBName        = @c_APP_DB_Name        
               , @bSuccess          = @b_Success OUTPUT        
               , @nErr              = @n_Err OUTPUT        
               , @cErrMsg           = @c_ErrMsg OUTPUT        
          
         IF @n_Err <> 0 AND ISNULL(@c_ErrMsg,'') <> ''        
         BEGIN        
            PRINT @c_ErrMsg        
            RETURN        
         END        
      END TRY        
      BEGIN CATCH        
         SET @c_ErrMsg = ERROR_MESSAGE()        
         PRINT @c_ErrMsg        
        
         GOTO QUIT        
      END CATCH        
        
      RETURN        
  END -- IF @c_QCmdFlag = 1        
        
  DECLARE  @t_BartenderCommand  TABLE        
   (   [ID]    [INT] IDENTITY(1,1) NOT NULL        
      --,RecNo    INT        
      ,PARM01  NVARCHAR(80)        
      ,PARM02  NVARCHAR(80)        
      ,PARM03  NVARCHAR(80)        
      ,PARM04  NVARCHAR(80)        
      ,PARM05  NVARCHAR(80)        
      ,PARM06  NVARCHAR(80)        
      ,PARM07  NVARCHAR(80)        
      ,PARM08  NVARCHAR(80)        
      ,PARM09  NVARCHAR(80)        
      ,PARM10  NVARCHAR(80)        
      ,KEY01   NVARCHAR(60)        
      ,KEY02 NVARCHAR(60)        
      ,KEY03   NVARCHAR(60)        
      ,KEY04   NVARCHAR(60)        
      ,KEY05   NVARCHAR(60)        
      ,BatchNo   INT NULL DEFAULT 1            --(CS27)        
   )        
        
  DECLARE @t_BartenderCommand_table TABLE        
   (   [ID]    [INT] IDENTITY(1,1) NOT NULL        
      --,RecNo    INT        
      ,PARM01  NVARCHAR(80)        
      ,PARM02  NVARCHAR(80)        
      ,PARM03  NVARCHAR(80)        
      ,PARM04  NVARCHAR(80)        
      ,PARM05  NVARCHAR(80)        
      ,PARM06  NVARCHAR(80)        
      ,PARM07  NVARCHAR(80)        
      ,PARM08  NVARCHAR(80)        
      ,PARM09  NVARCHAR(80)        
      ,PARM10  NVARCHAR(80)        
      ,KEY01   NVARCHAR(60)        
      ,KEY02   NVARCHAR(60)        
      ,KEY03   NVARCHAR(60)        
      ,KEY04  NVARCHAR(60)        
      ,KEY05   NVARCHAR(60)        
      ,BatchNo   INT NULL DEFAULT 0            --(CS27)        
   )        
        
  CREATE TABLE [#Result] (        
      [RowID] [INT] IDENTITY(1,1) NOT NULL,        
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
        
    DECLARE @n_IsRDT INT                       --CS07        
    EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT     --CS07        
        
    DECLARE @PrintLog TABLE (        
      [PID] [INT] IDENTITY(1,1) NOT NULL,        
      [serialno]    INT ,        
      [RowID]      INT ,        
      [Field01] [NVARCHAR] (80) NULL,        
      [Field02] [NVARCHAR] (80) NULL,        
      [Field03] [NVARCHAR] (80) NULL,        
      [logdate] datetime  NOT NULL DEFAULT (getdate()),        
      [NextRow] NVARCHAR(1) NOT NULL DEFAULT 'N')        
        
     --CS42 START        
     DECLARE @ResultZPL TABLE (        
     [PrinterName]   [NVARCHAR] (500) NULL,        
     [TemplatePath]  [NVARCHAR] (1000) NULL,        
     [CmdArgs]      [NVARCHAR] (500) NULL,        
     [PrintID]       [NVARCHAR] (80) NULL,        
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
  --CS42 END        
        
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
   SET @n_ReTry      = 0        
   SET @n_MaxTry     = 5        
   SET @n_StartCNT   = 1        
   SET @n_CntPBatch  = 1        
   SET @n_Batch = 1         --(CS23)        
   SET @n_CNTBatchRec = 1   --(CS23)        
   SET @n_CntBarRec = 0     --(CS23)        
   SET @n_CNTBatch = 0      --(CS28)        
   SET @n_CntPrnLogTBL = 0  --(CS28)        
   SET @n_Status_Out = 0    --(CS36)        
   SET @c_StopBatch  = 'N'        
   SET @n_TextMaxLength = 4000  --(CS23)        
   SET @n_TextLength  = 0       --(CS23)        
   SET @c_getFullText = ''        
   SET @c_BartenderCommand = ''        
   SET @c_BartenderFCommand = ''        
   SET @c_ExceedMaxLength ='N'        
   SET @c_LastRec = 'N'        
   SET @c_RemainText = ''        
   SET @c_GetKey05 = ''    --CS27        
   SET @n_BatchCnt = 0     --CS27        
   SET @c_GetRecNo = '1'        
   SET @c_ZPLPrint = 'N'   --CS42        
        
   SET @d_step1 = GETDATE() -- (CS35)        
        
   /*CS24 start*/        
   IF ISNULL(@c_StartRec,'') <> '' AND ISNULL(@c_ENDRec,'') <> ''        
   BEGIN        
      SET @n_TTLREC = (CONVERT(INT,@c_EndRec) - CONVERT(INT,@c_StartRec)) + 1        
      IF @n_TTLREC <=0        
      BEGIN        
         SELECT @n_err = 82557        
         SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': 1st Record no : ' + @c_StartRec        
           + ' is greater than last record no ' + @c_EndRec +  ' (isp_BT_GenBartenderCommand) '        
         SET @c_result = @c_errmsg        
        
         IF @c_Returnresult = 'Y'        
         BEGIN        
            SELECT @c_result as c_Result        
         END        
         GOTO QUIT        
      END        
   END        
        
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
        
   WHILE @@TRANCOUNT > 0        
   COMMIT TRAN        
        
   IF @b_Debug = '2'        
   BEGIN        
       PRINT CONVERT(NVARCHAR(20) ,GETDATE() ,120)        
   END        
        
   SELECT @n_err = 0        
         ,@c_errmsg = ''        
        
   /*CS01 End*/        
   SET @cSQL = ''        
   IF @c_StorerKey <> '' AND @c_StorerKey IS NOT NULL        
   BEGIN        
      SELECT @cSQL = SQL_Select        
      FROM   BartenderCmdConfig WITH (NOLOCK)        
      WHERE  LabelType = @c_LabelType        
      AND    type02 = @c_StorerKey        
   END        
        
   IF  @cSQL IS NULL OR @cSQL = ''        
   BEGIN        
      SELECT @cSQL = SQL_Select        
      FROM   BartenderCmdConfig WITH (NOLOCK)        
      WHERE  LabelType = @c_LabelType        
   END        
        
   /*CS01 Start*/        
   IF @cSQL IS NULL OR @cSQL = ''        
   BEGIN        
      SELECT @n_err = 82553        
      SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5) ,@n_err) + ': SQL Select field no set up for label type ' + @c_LabelType +        
                         ' (isp_BT_GenBartenderCommand) '        
        
      SET @c_result = 'label type : ' + @c_LabelType + '' + @c_errmsg --CS04        
        
      IF @c_Returnresult = 'Y'        
      BEGIN        
       SELECT @c_result AS c_Result        
      END        
        
      GOTO QUIT        
   END        
   /*CS01 End*/        
        
   IF @b_debug = '2'        
   BEGIN        
      PRINT @cSQL        
      PRINT 'PrinterId ' +  @cPrinterID        
   END        
        
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
            (@c_userID          ,rdt.rdt_RDTUserEncryption(UPPER(@c_userID),'EXceedUser')    ,@c_userID        
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
             UserName             ,PASSWORD            ,FullName        
            ,DefaultStorer        ,DefaultFacility     ,DefaultLangCode        
            ,DefaultMenu          ,DefaultUOM          ,DefaultPrinter        
            ,DefaultPrinter_Paper ,sqluseradddate      )        
         VALUES        
           (        
             @c_GetUserID   ,rdt.rdt_RDTUserEncryption(UPPER(@c_GetUserID),'EXceedUser')     ,@c_GetUserID        
            ,''             ,''              ,'ENG'        
            ,5              ,'6'           ,''        
            ,''             ,GETDATE()           )        
        
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
         ELSE        
         BEGIN        
            SELECT @c_Printername = Left(RP.winprinter, CharIndex(',', RP.winprinter + ',')-1),  --CS05        
                  @cPrinterID = RP.PrinterID        
            FROM rdt.RDTMOBREC RMR WITH (NOLOCK) JOIN rdt.rdtprinter RP WITH (NOLOCK)        
                                   ON RMR.Printer = RP.PrinterID        
            WHERE RMR.Username = @c_GetUserID        
         END        
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
            + ' with username ' + @c_userID +  ' (isp_BT_GenBartenderCommand) '        
      SET @c_result = @c_errmsg        --CS04        
        
      IF @c_Returnresult = 'Y'        
      BEGIN        
         SELECT @c_result as c_Result        
      END        
        
      GOTO QUIT        
   END 
   
   SET @c_JobType = ''                                                                             --(Wan02) - START
   IF @n_JobID > 0
   BEGIN
      SELECT TOP 1 @c_JobType = rpj.JobType
      FROM rdt.RDTPrintJob AS rpj WITH (NOLOCK) WHERE rpj.JobId = @n_JobID
      
      IF @c_JobType = ''
      BEGIN
         SELECT TOP 1 @c_JobType = rpjl.JobType
         FROM rdt.RDTPrintJob_Log AS rpjl WITH (NOLOCK) WHERE rpjl.JobId = @n_JobID
      END
      SELECT @n_PrintOverInternet = dbo.fnc_GetCloudPrint ('', @c_JobType, @cPrinterID) 
   END
   
   IF @c_JobType <> ''                                                                 --2023-11-15
   BEGIN
      SELECT @n_PrintOverInternet = dbo.fnc_GetCloudPrint ('', @c_JobType, @cPrinterID) 
   END              
   --SELECT @n_PrintOverInternet = IIF(cpc.PrintClientID= rp.CloudPrintClientID,1,0)  --(Wan01)
   --FROM rdt.RDTPrinter AS rp WITH (NOLOCK)
   --LEFT OUTER JOIN dbo.CloudPrintConfig AS cpc WITH (NOLOCK) ON cpc.PrintClientID = rp.CloudPrintClientID 
   --WHERE rp.PrinterID = @cPrinterID                                                              --(Wan02) - END
        
   -----------------------------------------------------------        
   /* Assign Different Path/TCP Port base on Printer Group */        
   -----------------------------------------------------------        
   SET @c_IniFilePath = ''        
   SET @c_RemoteEndPoint = ''        
        
   SELECT TOP 1        
          @c_IniFilePath = c.UDF01        
         ,@c_RemoteEndPoint = c.Long        
   FROM   CODELKUP c WITH (NOLOCK)        
   JOIN   rdt.RDTPrinter prt WITH (NOLOCK) ON prt.PrinterGroup = C.StorerKey        
   WHERE  ListName = 'TCPClient'        
   AND    c.Short = 'BARTENDER'        
   AND    prt.PrinterID = @cPrinterID        
        
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
       SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5) ,@n_err) + ': CODELKUP INI file path Not Setup. (isp_BT_GenBartenderCommand) '        
       SET @c_result = @c_result + @c_errmsg --CS04        
                                             --GOTO QUIT        
   END        
        
   IF @c_RemoteEndPoint IS NULL  OR @c_RemoteEndPoint = ''        
   BEGIN        
       SELECT @n_err = 82552        
       SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5) ,@n_err) + ': CODELKUP Remote End point Not setup. (isp_BT_GenBartenderCommand) '        
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
        
   SET @c_CopyPrint = 'C='+ @c_Copy        
        
   IF @c_Parm10 = 'B'  --CS36 start        
   BEGIN        
      INSERT INTO @t_BartenderCommand_table(        
         PARM01      ,PARM02      ,PARM03        
         ,PARM04      ,PARM05      ,PARM06        
         ,PARM07      ,PARM08      ,PARM09        
         ,PARM10      ,KEY01       ,KEY02        
         ,KEY03       ,KEY04       ,KEY05)        
      EXEC sp_executesql @cSQL,        
            N'@Parm01 nvarchar(80) ,@Parm02 nvarchar(80) ,@Parm03 nvarchar(80)        
         ,@Parm04 nvarchar(80)   ,@Parm05 nvarchar(80) ,@Parm06 nvarchar(80)        
         ,@Parm07 nvarchar(80)   ,@Parm08 nvarchar(80) ,@Parm09 nvarchar(80)        
         ,@Parm10 nvarchar(80)   ,@NCopy nvarchar(10)  '        
         ,@c_Parm01, @c_Parm02 ,@c_Parm03        
         ,@c_Parm04, @c_Parm05 ,@c_Parm06        
         ,@c_Parm07, @c_Parm08 ,@c_Parm09        
         ,@c_Parm10,@c_NoCopy        
        
      INSERT INTO @t_BartenderCommand(PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10        
                              ,Key01,Key02,Key03,Key04,Key05,BatchNo)  --(CS27)        
      SELECT PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10        
            ,Key01,Key02,Key03,Key04,Key05,BatchNo      --(CS27)        
      FROM @t_BartenderCommand_table        
      WHERE ID >= CASE WHEN ISNULL(@c_startRec,'') <> '' THEN CONVERT(INT,@c_startRec) ELSE ID END        
      AND ID<=CASE WHEN ISNULL(@c_EndRec,'') <> '' THEN CONVERT(INT,@c_EndRec) ELSE ID END  --(CS24)        
      ORDER BY ID       --CS_sort_fix        
   END        
   ELSE        
   BEGIN        
      INSERT INTO @t_BartenderCommand(PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10        
                                    ,Key01,Key02,Key03,Key04,Key05)        
      EXEC sp_executesql @cSQL,        
         N'@Parm01 nvarchar(80) ,@Parm02 nvarchar(80) ,@Parm03 nvarchar(80)        
         ,@Parm04 nvarchar(80)   ,@Parm05 nvarchar(80) ,@Parm06 nvarchar(80)        
         ,@Parm07 nvarchar(80)   ,@Parm08 nvarchar(80) ,@Parm09 nvarchar(80)        
         ,@Parm10 nvarchar(80)   ,@NCopy nvarchar(10)  '        
         ,@c_Parm01, @c_Parm02 ,@c_Parm03        
         ,@c_Parm04, @c_Parm05 ,@c_Parm06        
         ,@c_Parm07, @c_Parm08 ,@c_Parm09        
         ,@c_Parm10,@c_NoCopy        
   END --CS36 END        
        
   SET @d_Trace_Step1 = GETDATE()        
        
   SET @d_step1 = GETDATE() - @d_step1 -- (CS35)        
   SET @d_step2 = GETDATE() -- (CS35)        
        
   IF @b_debug='5'        
   BEGIN        
      select @cSQL    
      SELECT '2','t_BartenderCommand_table',* FROM @t_BartenderCommand_table        
      SELECT '2','t_BartenderCommand',* FROM @t_BartenderCommand      
   END        
        
   IF @b_debug='2'        
   BEGIN        
      PRINT 'start'        
   END        
        
   /*CS27 start*/        
   IF @c_Parm10 = 'B'  --CS36 start        
   BEGIN        
      DECLARE CUR_BartenderCommandLoop1 CURSOR LOCAL FAST_FORWARD READ_ONLY        
      FOR        
          SELECT ID,PARM01  ,PARM02 ,PARM03        
                ,PARM04  ,PARM05 ,PARM06        
                ,PARM07  ,PARM08 ,PARM09        
                ,PARM10        
                ,KEY01   ,KEY02  ,KEY03        
                ,KEY04   ,KEY05        
          FROM   @t_BartenderCommand        
          ORDER BY ID        
        
      IF @b_debug='2'        
      BEGIN        
         SELECT 'Check start 1234'        
      END        
        
      OPEN CUR_BartenderCommandLoop1        
        
      FETCH NEXT FROM CUR_BartenderCommandLoop1        
      INTO @n_LCmdCounter,@c_BT_LParm01, @c_BT_LParm02, @c_BT_LParm03,        
          @c_BT_LParm04, @c_BT_LParm05, @c_BT_LParm06,        
           @c_BT_LParm07, @c_BT_LParm08, @c_BT_LParm09,        
           @c_BT_LParm10, @c_LKEY01, @c_LKEY02,        
           @c_LKEY03, @c_LKEY04, @c_LKEY05--,@n_Batch        
        
      WHILE @@FETCH_STATUS <> -1        
      BEGIN        
         IF @c_LKEY05 <> @c_GetKey05        
         BEGIN        
              SET @n_BatchCnt = @n_BatchCnt + 1        
              SET @c_GetKey05 = @c_LKEY05        
         END        
        
         SELECT @n_CNTBatch = Count(1)        
         FROM @t_BartenderCommand        
         WHERE Batchno = @n_BatchCnt   
        
         IF ISNULL(@c_StartRec,'') ='' AND @c_Parm10 <> 'B'         --(CS34a)        
         BEGIN        
           SET @n_BatchCnt = @n_BatchCnt + 1        
         END        
        
         Update @t_BartenderCommand        
         Set Batchno = @n_BatchCnt        
         where ID = @n_LCmdCounter        
        
         FETCH NEXT FROM CUR_BartenderCommandLoop1        
         INTO @n_LCmdCounter,@c_BT_LParm01, @c_BT_LParm02, @c_BT_LParm03,        
                @c_BT_LParm04, @c_BT_LParm05, @c_BT_LParm06,        
                @c_BT_LParm07, @c_BT_LParm08, @c_BT_LParm09,        
                @c_BT_LParm10, @c_LKEY01, @c_LKEY02,        
                @c_LKEY03, @c_LKEY04, @c_LKEY05        
      END --WHILE @@FETCH_STATUS <> -1        
      CLOSE CUR_BartenderCommandLoop1        
      DEALLOCATE CUR_BartenderCommandLoop1        
   END --CS36 END        
        
   IF @b_debug='5'        
   BEGIN        
      select'3333',* from @t_BartenderCommand        
   END        
        
   IF @c_Parm10 = 'B'  --CS36 start        
   BEGIN        
      SELECT @n_CntPBatch = MAX(Batchno)        
      FROM   @t_BartenderCommand        
      /*CS28 start*/        
      IF @n_CntPBatch = 0        
      BEGIN        
         SET @n_CntPBatch = 1        
        
         UPDATE @t_BartenderCommand        
         SET batchno=1        
         Where batchno=0        
      END        
   END --CS36 END        
print'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
   WHILE @n_StartCNT <= @n_CntPBatch --CS27        
   BEGIN        
      SELECT @n_CntBarRec = count(1)        
      FROM @t_BartenderCommand        
      WHERE Batchno  = @n_StartCNT        
        
      IF @b_debug='5'        
      BEGIN        
        SELECT 'Bartender batch Cnt', @n_CntPBatch as TTLCnt, 'start cnt' ,@n_StartCNT as startCnt,'@n_CntBarRec',@n_CntBarRec        
      END        
        
      DECLARE CUR_BartenderCommandLoop CURSOR LOCAL FAST_FORWARD READ_ONLY        
      FOR        
        SELECT ROW_NUMBER() OVER (ORDER BY ID) AS ID,   --CS28        
               PARM01  ,PARM02 ,PARM03        
              ,PARM04  ,PARM05 ,PARM06        
              ,PARM07  ,PARM08 ,PARM09        
              ,PARM10        
              ,KEY01   ,KEY02  ,KEY03        
              ,KEY04   ,KEY05        
        FROM   @t_BartenderCommand        
        WHERE Batchno  = @n_StartCNT        
        Order by ID        
        
      IF @b_debug='5'        
      BEGIN        
         SELECT 'Bartender 11', @n_CntBarRec as TTLCnt        
         SELECT * FROM @t_BartenderCommand WHERE Batchno  = @n_StartCNT        
         PRINT @cSQL        
         --GOTO QUIT        
      END        
        
      OPEN CUR_BartenderCommandLoop        
        
      FETCH NEXT FROM CUR_BartenderCommandLoop        
      INTO @n_CmdCounter,@c_BT_Parm01, @c_BT_Parm02, @c_BT_Parm03,        
            @c_BT_Parm04, @c_BT_Parm05, @c_BT_Parm06,        
            @c_BT_Parm07, @c_BT_Parm08, @c_BT_Parm09,        
            @c_BT_Parm10, @c_KEY01, @c_KEY02,        
            @c_KEY03, @c_KEY04, @c_KEY05--,@n_Batch        
        
      WHILE @@FETCH_STATUS <> -1        
      BEGIN        
         IF @n_StartCNT > 1      --CS36 start        
         BEGIN        
            IF EXISTS (SELECT 1        
               FROM #RESULT R WITH (NOLOCK)        
               JOIN @t_BartenderCommand BC  ON BC.PARM02 = R.Col02        
               WHERE BC.BatchNo =(@n_StartCNT - 1)  ) OR ISNULL(@c_Parm10,'') <> 'B'             --(CS31)        
            BEGIN        
               TRUNCATE TABLE #RESULT        
            END        
         END        
         IF @b_debug='2'        
         BEGIN        
            PRINT 'start main loop'        
         END        

         SELECT        
             @c_TemplatePath = TemplatePath        
            ,@c_SubSP = StoreProcedure        
            ,@c_logfile = LogFile              --(CS25)        
            ,@c_Field01 = Field01              --(CS25)        
            ,@c_Field02 = Field02              --(CS25)        
            ,@c_Field03 = Field03              --(CS25)        
            ,@c_BTPrinterID = ISNULL(BTPrinterID,'')      --(CS34)        
            ,@c_FilePath    = FilePath                    --(CS42)        
            ,@c_ZPLPrint = ISNULL(ZPLPRINTING,'0')        --(CS42)        
         FROM  BartenderLabelCfg WITH (NOLOCK)        
         WHERE LabelType = @c_LabelType        
         AND   Key01 = CASE        
                          WHEN ISNULL(@c_KEY01 ,'') <> '' THEN @c_KEY01        
                          ELSE Key01        
                       END        
         AND   Key02 = CASE        
                 WHEN ISNULL(@c_KEY02 ,'') <> '' THEN @c_KEY02        
                          ELSE Key02        
                       END        
         AND   Key03 = CASE        
                          WHEN ISNULL(@c_KEY03 ,'') <> '' THEN @c_KEY03        
                          ELSE Key03        
                       END        
         AND   Key04 = CASE        
                          WHEN ISNULL(@c_KEY04 ,'') <> '' THEN @c_KEY04        
                          ELSE Key04        
                       END        
         AND   Key05 = CASE        
                         WHEN ISNULL(@c_KEY05 ,'') <> '' THEN UPPER(@c_KEY05)        
                          ELSE Key05        
                       END        
         AND   StorerKey = ISNULL(@c_StorerKey ,'')     

         print @@rowcount   
        print'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111111111111111111'
        print @c_LabelType  
        print @c_storerkey
        print @c_SubSP
        print @c_KEY01
        print @c_KEY02
         print @c_KEY03
          print @c_KEY04
           print @c_KEY05

         IF @b_Debug = '5'        
         BEGIN        
            PRINT  'Template Path ' + @c_TemplatePath  + ' And file path ' + @c_tempfilepath        
            PRINT ' initial full text ' + @c_GetFulltext        
            PRINT 'lenght fulltext : ' + convert(nvarchar(5),LEN(@c_GetFulltext))        
            PRINT 'Logfile : ' + @c_logfile       
            PRINT '@c_ZPLPrint' +  @c_ZPLPrint     
         END        
        
         /*CS01 Start*/        
         IF @c_TemplatePath IS NULL OR @c_TemplatePath = ''  --OR  ISNULL(@c_tempfilepath,'')=''        
         BEGIN        
            SELECT @n_err = 82555        
            SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': Label template path not setup for label type: ' + ISNULL(RTRIM(@c_LabelType),'')        
                             + ', Key01: ' + ISNULL(RTRIM(@c_KEY01),'') + ', Key02: ' + ISNULL(RTRIM(@c_KEY02),'')        
                             + ', Key03: ' + ISNULL(RTRIM(@c_KEY03),'') + ', Key04: ' + ISNULL(RTRIM(@c_KEY04),'')        
                             + ', Key05: ' + ISNULL(RTRIM(@c_KEY05),'')        
                             + ', StorerKey: ' + ISNULL(RTRIM(@c_storerkey),'')        
                             + '. (isp_BT_GenBartenderCommand) ' --(L01)        
        
            SET @c_result = @c_errmsg        --CS04        
        
            IF @c_Returnresult = 'Y'        
            BEGIN        
               SELECT @c_result as c_Result        
            END        
        
            GOTO QUIT        
         END        
        
         --CS42 START        
         IF @c_ZPLPRINT = '1'        
         BEGIN        
            IF ISNULL(@c_FilePath,'') = ''        
            BEGIN        
               SELECT @n_err = 82560        
               SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': PRN path not setup while ZPL Print Flag is turn on (isp_BT_GenBartenderCommand) '        
               SET @c_result = @c_errmsg        --CS04        
        
               IF @c_Returnresult = 'Y'        
               BEGIN        
                  SELECT @c_result as c_Result        
               END        
               GOTO QUIT        
            END      
         END        
       --CS42 END        
        
         IF @c_SubSP IS NULL OR @c_SubSP = ''        
         BEGIN        
             SELECT @n_err = 82556        
             SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': sub SP not setup for label type  : ' + @c_LabelType + ' (isp_BT_GenBartenderCommand) '        
             SET @c_result = @c_errmsg        --CS04        
        
             IF @c_Returnresult = 'Y'        
             BEGIN        
                SELECT @c_result as c_Result        
             END        
             GOTO QUIT        
         END        
        
         /*CS01 End*/        
        
         SET @c_SqlString = N' Exec ' + @c_SubSP + ' @Parm01,@Parm02 ,@Parm03,@Parm04,@Parm05,@Parm06,@Parm07,@Parm08,@Parm09,@Parm10'        
            

         IF @b_debug = '2'        
         BEGIN        
           Print @c_SqlString        
           SELECT 'Cnt' , @n_StartCnt        
         END        
        
         /*CS23 Start*/        
         IF ISNULL(@c_TemplatePath ,'') <> ''        
         BEGIN        
            /*CS34 Start*/        
            IF ISNULL(@c_BTPrinterID,'') <> ''        
            BEGIN        
               SELECT @c_Printername = LEFT(rp.winprinter ,CHARINDEX(',' ,rp.winprinter + ',') -1)--(Wan01)
                     --,@n_PrintOverInternet = IIF(cpc.PrintClientID = rp.CloudPrintClientID,1,0)  --(Wan02) 
               FROM rdt.RDTPrinter AS rp WITH (NOLOCK)
               --LEFT OUTER JOIN dbo.CloudPrintConfig AS cpc WITH (NOLOCK)                         --(Wan02) 
               --              ON cpc.PrintClientID = rp.CloudPrintClientID                        --(Wan02) 
               WHERE rp.PrinterID = @c_BTPrinterID  
               
               IF @c_JobType <> ''                                                                 --2023-11-15
               BEGIN
                  SELECT @n_PrintOverInternet = dbo.fnc_GetCloudPrint ('', @c_JobType, @c_BTPrinterID)--(Wan02)     
               END
         --CS41a Start        
               SELECT TOP 1 @c_RemoteEndPoint = c.Long        
               FROM   CODELKUP c WITH (NOLOCK)        
               JOIN   rdt.RDTPrinter prt WITH (NOLOCK) ON prt.PrinterGroup = C.Storerkey        
               WHERE  ListName = 'TCPClient'        
               AND    c.Short = 'BARTENDER'        
               AND    prt.PrinterID = @c_BTPrinterID        
            --CS41a End        
            END        
        
            IF ISNULL(RTRIM(@c_Printername),'') = '' OR ISNULL(RTRIM(@cPrinterID),'') = ''        
            BEGIN        
               SELECT @n_err = 82558        
               SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': Printer not setup for printer ID : ' + @cPrinterID        
                   + ' for labeltype ' + @c_LabelType +  ' (isp_BT_GenBartenderCommand) '        
               SET @c_result = @c_errmsg        --CS04        
        
               IF @c_Returnresult = 'Y'        
               BEGIN        
                 SELECT @c_result as c_Result        
               END        
        
               GOTO QUIT        
            END        
        
            /*CS34 End*/        
            SET @c_PrintJobName = ISNULL(RTRIM(@c_userid),'') + ISNULL(RTRIM(@c_Printername),'') + RTRIM(@c_LabelType) +        
                               convert(varchar(8),getdate(),112)+convert(varchar(10),getdate(),114) +        
                               --case when @n_CntBarRec = 1 then convert(nvarchar(10),@c_ID) Else convert(nvarchar(10),@n_CmdCounter) END --RTRIM(@c_ID)   --CS16        
                               case when @n_CntBarRec = 1 then convert(nvarchar(10),RTRIM(@n_StartCnt)) Else convert(nvarchar(10),@n_CmdCounter) END    --CS41a        
        
            IF @b_Debug ='1'        
            BEGIN        
             PRINT ' Print job name is :  ' + @c_PrintJobName + ' with No of copy is : ' + @c_CopyPrint        
            END        
         END        
        
         SET @c_BartenderHCommand = ''        
         SET @c_BartenderHCommand = '%BTW% /AF="' + @c_TemplatePath + '" /PRN="' + @c_Printername +        
             '" /PrintJobName="' + REPLACE(@c_PrintJobName,':','') + '" /R=3 /' + @c_CopyPrint + ' /P /D="%Trigger File Name%" '        
         SET @c_BartenderHCommand = RTRIM(@c_BartenderHCommand) + @c_NewLineChar +  '%END%'        
         SET @c_BartenderHCommand = RTRIM(@c_BartenderHCommand) + @c_NewLineChar +  @c_HeaderText        

         /*CS23 End*/        
         INSERT INTO #Result                          --CS36        
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
        
         SELECT @n_cnt = @@ROWCOUNT        
         SET @d_Trace_Step1 = GETDATE()        
         SET @d_step2 = GETDATE() - @d_step2 -- (CS35)        
         SET @d_step3 = GETDATE()            -- (CS35)        
        
        
 print'jhubbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
 print @c_SqlString
 print   @c_BT_Parm01        
  print @c_BT_Parm02        
 print @c_BT_Parm03        
  print @c_BT_Parm04        
  print  @c_BT_Parm05        
 print @c_BT_Parm06        
 print @c_BT_Parm07        
  print @c_BT_Parm08        
  print @c_BT_Parm09        
  print @c_BT_Parm10 
  print'----------------------'

         IF @b_debug = '2'        
         BEGIN        
            SELECT *  FROM  #Result        
         END        
        
         SET @c_counter = 100        
         IF @n_cnt <> 0        
         BEGIN  -- begin cnt        
            SET @c_SubFullText =''        
            SET @n_CommandLength = 0        
            SET @n_TextLength = 0        
        
            DECLARE CUR_BartenderSPLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
            SELECT CONVERT(NVARCHAR(10),RowID),        
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
              ORDER BY rowID        
 /*CS18 End */        
              IF @b_debug='5'        
              BEGIN        
                 SELECT 'Result table Check'        
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
               IF @n_cnt > 1 OR @c_Parm10='B'   --CS36 start        
               BEGIN        
                  SELECT @c_GetRecNo = ISNULL(BC.ID,'1')        
                  FROM @t_BartenderCommand BC        
                  JOIN #Result R WITH (NOLOCK) ON R.col02=BC.PARM02        
                  WHERE R.col02 = @c_col02        
               END        
        
               IF @b_debug = '2'        
               BEGIN        
                  SELECT c_GetRecNo = ISNULL(BC.ID,'1'),c_col02 = R.col02        
                  FROM @t_BartenderCommand BC        
                  JOIN #Result R WITH (NOLOCK) ON R.col02=BC.PARM02        
                  WHERE R.col02 = @c_col02        
               END        
        
               /*CS25 End*/        
               SET @c_Fulltext = ''        
               SET @c_Fulltext = '"' + LTRIM(RTRIM(ISNULL(@c_GetRecNo,''))) + '"'        
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
               IF @b_debug='7' --and  @n_CmdCounter>=29        
               BEGIN        
        
                  PRINT 'loop with ID : ' + convert(nvarchar(5),@n_CmdCounter)        
                  PRINT 'loop full text : '  + @c_Fulltext        
                  PRINT 'loop sub full text : ' + @c_SubFullText        
                  print '55'        
               END        
        
               IF ISNULL(@c_SubFullText,'') = ''        
               BEGIN        
                  SET @c_SubFullText = @c_Fulltext        
               END        
               ELSE        
               BEGIN        
                  SET @c_SubFullText = @c_SubFullText + @c_NewLineChar + @c_Fulltext        
               END        
               IF @b_debug='7' --and  @n_CmdCounter>=29        
               BEGIN        
                  PRINT 'assign loop sub full text : ' + @c_SubFullText        
                  print '66'        
               END        
        
               --CS42 START        
               IF @c_ZPLPRINT = '1'        
               BEGIN        
                  set @c_ZPLPrinterName = ''    
                  SET @c_ZPLPrinterName= '\\' + substring(@c_RemoteEndPoint,1,CHARINDEX(':',@c_RemoteEndPoint)-1) + '\' + @c_Printername    
    
                  INSERT INTO @ResultZPL (PrinterName,TemplatePath,CmdArgs,PrintID,Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09        
                                    ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22        
                                    ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34        
                                    ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44        
                                    ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54        
                                    ,Col55,Col56,Col57,Col58,Col59,Col60)        
                   VALUES(@c_ZPLPrinterName,@c_filepath,'',@c_GetRecNo,@c_Col01, @c_Col02,@c_Col03,@c_Col04, @c_Col05,@c_Col06, @c_Col07,@c_Col08,@c_Col09,@c_Col10,        
                          @c_Col11, @c_Col12,@c_Col13,@c_Col14, @c_Col15,@c_Col16, @c_Col17,@c_Col18,@c_Col19,@c_Col20,        
                          @c_Col21, @c_Col22,@c_Col23,@c_Col24, @c_Col25,@c_Col26, @c_Col27,@c_Col28,@c_Col29,@c_Col30,        
                          @c_Col31, @c_Col32,@c_Col33,@c_Col34, @c_Col35,@c_Col36, @c_Col37,@c_Col38,@c_Col39,@c_Col40,        
                          @c_Col41, @c_Col42,@c_Col43,@c_Col44, @c_Col45,@c_Col46, @c_Col47,@c_Col48,@c_Col49,@c_Col50,        
                          @c_Col51, @c_Col52,@c_Col53,@c_Col54, @c_Col55,@c_Col56, @c_Col57,@c_Col58,@c_Col59,@c_Col60)        
        
               END        
               --CS42 END        
        
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
        
            IF @b_debug='5'        
            BEGIN        
               SELECT *  FROM  #Result        
               PRINT ' counter 1 ' + convert(nvarchar(10),@c_counter) + 'with CID : ' + convert(nvarchar(10),@c_ID)    --(CS19)        
               PRINT ' Get Full text : ' + @c_SubFullText        
               PRINT ' check Full commander command : ' + @c_BartenderFCommand        
               PRINT ' lenght command ' + convert(nvarchar(10),LEN(@c_BartenderFCommand + @c_Fulltext)  )        
               --GOTO QUIT;        
            END        
        
            /*CS25 Start*/        
            IF @c_LogFile = 'Y' AND @c_Parm10='B' --CS36        
            BEGIN        
               SET @c_ExecStatements = ''        
               SET @c_ExecArguments = ''        
               /*CS30a start*/        
        
               SELECT @c_GetField01 = CASE @c_field01        
               WHEN 'Col01' THEN Col01 WHEN 'Col02' THEN Col02 WHEN 'Col03' THEN Col03        
               WHEN 'Col04' THEN Col04 WHEN 'Col05' THEN Col05 WHEN 'Col06' THEN Col06        
               WHEN 'Col07' THEN Col07 WHEN 'Col08' THEN Col08 WHEN 'Col09' THEN Col09        
               WHEN 'Col10' THEN Col10 WHEN 'Col11' THEN Col11 WHEN 'Col12' THEN Col12        
               WHEN 'Col13' THEN Col13 WHEN 'Col14' THEN Col14 WHEN 'Col15' THEN Col15        
               WHEN 'Col16' THEN Col16 WHEN 'Col17' THEN Col17 WHEN 'Col18' THEN Col18        
               WHEN 'Col19' THEN Col19 WHEN 'Col20' THEN Col20 WHEN 'Col21' THEN Col21        
               WHEN 'Col22' THEN Col22 WHEN 'Col23' THEN Col23 WHEN 'Col24' THEN Col24        
               WHEN 'Col25' THEN Col25 WHEN 'Col26' THEN Col26 WHEN 'Col27' THEN Col27        
               WHEN 'Col28' THEN Col28 WHEN 'Col28' THEN Col28 WHEN 'Col29' THEN Col29        
               WHEN 'Col30' THEN Col30 WHEN 'Col31' THEN Col31 WHEN 'Col32' THEN Col32        
               WHEN 'Col33' THEN Col33 WHEN 'Col34' THEN Col34 WHEN 'Col35' THEN Col35        
               WHEN 'Col36' THEN Col36 WHEN 'Col37' THEN Col37 WHEN 'Col38' THEN Col38        
               WHEN 'Col39' THEN Col39 WHEN 'Col40' THEN Col40 WHEN 'Col41' THEN Col41        
               WHEN 'Col42' THEN Col42 WHEN 'Col43' THEN Col43 WHEN 'Col44' THEN Col44       
               WHEN 'Col45' THEN Col45 WHEN 'Col46' THEN Col46 WHEN 'Col47' THEN Col47        
               WHEN 'Col48' THEN Col48 WHEN 'Col49' THEN Col49 WHEN 'Col50' THEN Col50        
               WHEN 'Col51' THEN Col51 WHEN 'Col52' THEN Col52 WHEN 'Col53' THEN Col53        
               WHEN 'Col54' THEN Col54 WHEN 'Col55' THEN Col55 WHEN 'Col56' THEN Col56        
               WHEN 'Col57' THEN Col57 WHEN 'Col58' THEN Col58 WHEN 'Col59' THEN Col59        
               ELSE Col60 END,        
               @c_GetField02 = CASE @c_field02        
               WHEN 'Col01' THEN Col01 WHEN 'Col02' THEN Col02 WHEN 'Col03' THEN Col03        
               WHEN 'Col04' THEN Col04 WHEN 'Col05' THEN Col05 WHEN 'Col06' THEN Col06        
               WHEN 'Col07' THEN Col07 WHEN 'Col08' THEN Col08 WHEN 'Col09' THEN Col09        
               WHEN 'Col10' THEN Col10 WHEN 'Col11' THEN Col11 WHEN 'Col12' THEN Col12        
               WHEN 'Col13' THEN Col13 WHEN 'Col14' THEN Col14 WHEN 'Col15' THEN Col15        
               WHEN 'Col16' THEN Col16 WHEN 'Col17' THEN Col17 WHEN 'Col18' THEN Col18        
               WHEN 'Col19' THEN Col19 WHEN 'Col20' THEN Col20 WHEN 'Col21' THEN Col21        
               WHEN 'Col22' THEN Col22 WHEN 'Col23' THEN Col23 WHEN 'Col24' THEN Col24        
               WHEN 'Col25' THEN Col25 WHEN 'Col26' THEN Col26 WHEN 'Col27' THEN Col27        
               WHEN 'Col28' THEN Col28 WHEN 'Col28' THEN Col28 WHEN 'Col29' THEN Col29        
               WHEN 'Col30' THEN Col30 WHEN 'Col31' THEN Col31 WHEN 'Col32' THEN Col32        
               WHEN 'Col33' THEN Col33 WHEN 'Col34' THEN Col34 WHEN 'Col35' THEN Col35        
               WHEN 'Col36' THEN Col36 WHEN 'Col37' THEN Col37 WHEN 'Col38' THEN Col38        
               WHEN 'Col39' THEN Col39 WHEN 'Col40' THEN Col40 WHEN 'Col41' THEN Col41        
               WHEN 'Col42' THEN Col42 WHEN 'Col43' THEN Col43 WHEN 'Col44' THEN Col44        
               WHEN 'Col45' THEN Col45 WHEN 'Col46' THEN Col46 WHEN 'Col47' THEN Col47        
               WHEN 'Col48' THEN Col48 WHEN 'Col49' THEN Col49 WHEN 'Col50' THEN Col50        
               WHEN 'Col51' THEN Col51 WHEN 'Col52' THEN Col52 WHEN 'Col53' THEN Col53        
               WHEN 'Col54' THEN Col54 WHEN 'Col55' THEN Col55 WHEN 'Col56' THEN Col56        
               WHEN 'Col57' THEN Col57 WHEN 'Col58' THEN Col58 WHEN 'Col59' THEN Col59        
               ELSE Col60 END,        
               @c_GetField03 = CASE @c_field03        
               WHEN 'Col01' THEN Col01 WHEN 'Col02' THEN Col02 WHEN 'Col03' THEN Col03        
               WHEN 'Col04' THEN Col04 WHEN 'Col05' THEN Col05 WHEN 'Col06' THEN Col06        
               WHEN 'Col07' THEN Col07 WHEN 'Col08' THEN Col08 WHEN 'Col09' THEN Col09        
               WHEN 'Col10' THEN Col10 WHEN 'Col11' THEN Col11 WHEN 'Col12' THEN Col12        
               WHEN 'Col13' THEN Col13 WHEN 'Col14' THEN Col14 WHEN 'Col15' THEN Col15        
               WHEN 'Col16' THEN Col16 WHEN 'Col17' THEN Col17 WHEN 'Col18' THEN Col18        
               WHEN 'Col19' THEN Col19 WHEN 'Col20' THEN Col20 WHEN 'Col21' THEN Col21        
               WHEN 'Col22' THEN Col22 WHEN 'Col23' THEN Col23 WHEN 'Col24' THEN Col24        
               WHEN 'Col25' THEN Col25 WHEN 'Col26' THEN Col26 WHEN 'Col27' THEN Col27        
               WHEN 'Col28' THEN Col28 WHEN 'Col28' THEN Col28 WHEN 'Col29' THEN Col29        
               WHEN 'Col30' THEN Col30 WHEN 'Col31' THEN Col31 WHEN 'Col32' THEN Col32        
               WHEN 'Col33' THEN Col33 WHEN 'Col34' THEN Col34 WHEN 'Col35' THEN Col35        
               WHEN 'Col36' THEN Col36 WHEN 'Col37' THEN Col37 WHEN 'Col38' THEN Col38        
               WHEN 'Col39' THEN Col39 WHEN 'Col40' THEN Col40 WHEN 'Col41' THEN Col41        
               WHEN 'Col42' THEN Col42 WHEN 'Col43' THEN Col43 WHEN 'Col44' THEN Col44        
               WHEN 'Col45' THEN Col45 WHEN 'Col46' THEN Col46 WHEN 'Col47' THEN Col47        
               WHEN 'Col48' THEN Col48 WHEN 'Col49' THEN Col49 WHEN 'Col50' THEN Col50        
               WHEN 'Col51' THEN Col51 WHEN 'Col52' THEN Col52 WHEN 'Col53' THEN Col53        
               WHEN 'Col54' THEN Col54 WHEN 'Col55' THEN Col55 WHEN 'Col56' THEN Col56        
               WHEN 'Col57' THEN Col57 WHEN 'Col58' THEN Col58 WHEN 'Col59' THEN Col59        
               ELSE Col60 END        
               FROM #Result (nolock) where RowID=convert(int,@c_ID)        
        
               IF @b_debug = '9'        
               BEGIN        
                  PRINT '@c_GetField01  : ' + @c_GetField01 + ' , Field02 : ' + @c_GetField02        
                        + ', Field03 : ' +  @c_GetField03  + 'ID : '  + @c_ID        
               END        
        
               IF NOT EXISTS (SELECT 1 FROM @PrintLog WHERE Field01=@c_GetField01 AND Field02=@c_GetField02 AND Field03= @c_GetField03)        
               BEGIN        
                  INSERT INTO @PrintLog (RowID,SerialNo,Field01,Field02,Field03)        
                  VALUES(@c_ID,' ',@c_GetField01,@c_GetField02,@c_GetField03)        
               END        
            END        
        
            IF @b_Debug='5'  --and  @n_CmdCounter>=29        
            BEGIN        
               SELECT '@c_ID',@c_ID'total length',LEN(@c_BartenderFCommand + @c_Fulltext ),'Length scripts',LEN(@c_BartenderFCommand),'@c_BartenderFCommand'        
                        ,@c_BartenderFCommand,'length full text',LEN(@c_Fulltext),'Fulltext',@c_Fulltext,'Estimate Length',((LEN(@c_Fulltext)*20)/100)        
            END        
        
            IF CHARINDEX(@c_Fulltext,@c_BartenderFCommand) > 0        
            BEGIN        
                  SET @c_Fulltext = ''        
            END        
        
            IF ISNULL(@c_Parm10,'') = 'B'   --CS31        
            BEGIN                           --CS31        
               /*CS33*/        
               IF @b_debug='5'  --and  @n_CmdCounter>=29        
               BEGIN        
                  PRINT 'By Batch Start'        
               END        
        
               IF LEN(@c_BartenderFCommand) + LEN(@c_Fulltext)+((LEN(@c_Fulltext)*20)/100) >= 4000        
               BEGIN        
                  IF @b_debug='5'  --and  @n_CmdCounter>=29        
                  BEGIN        
                     PRINT  'Lenght over 4000'        
                     PRINT  'Check Command ' + @c_BartenderFCommand        
                     PRINT  'Check over Full Text :' + @c_FullText        
                     PRINT 'get CID: ' + convert(nvarchar(5),@c_ID)        
                  END        
                  /*Cs34a Start*/        
                  SET @c_GetFulltext = @c_SubFullText        
                  SET @c_BartenderCommand =  @c_GetFulltext        
                  SET @c_BartenderFCommand = @c_BartenderHCommand + @c_NewLineChar + @c_BartenderCommand        
                  /*Cs34a END*/        
                  SET @c_RemainText = ''        
                  SET @c_RemainText =  @c_FullText        
                  IF @b_debug='7'        
                  BEGIN        
                     PRINT  'Check over sub Full Text :' + @c_RemainText        
                  END        
        
                  UPDATE @PrintLog        
                  SET NextRow ='Y'        
                  WHERE Field02=@c_Col02        
        
                  DELETE #RESULT        
        
                  IF @b_debug='5'        
                  BEGIN        
                     SELECT 'Delete',@c_col02,* FROM #RESULT        
                     SELECT 'printlog', * from @PrintLog        
                  END        
        
                  If @b_debug ='3'        
                  BEGIN        
                        PRINT 'GO TO TCP Socket'        
                  END        
       
                  IF @n_CmdCounter = @n_CntBarRec --AND @n_StartCNT = @n_CntPBatch  --CS27        
                  BEGIN        
                     IF @b_debug='5'        
                     BEGIN        
                        PRINT 'Set Last Record : '        
                        PRINT 'last Full Text : ' + @c_FullText        
                        SELECT 'last record 1','@n_CmdCounter',@n_CmdCounter,'@n_CntBarRec',@n_CntBarRec        
                     END        
        
                     SET @c_LastRec = 'Y'        
                  END        
        
                  SET @n_CNTBatchRec = @n_CNTBatchRec - 1        
                  GOTO SEND_TCP_SOCKET        
               END        
               ELSE        
               BEGIN        
                  IF @b_debug='5'  --and  @n_CmdCounter>=6        
                  BEGIN        
                     PRINT 'loop with ID : ' + convert(nvarchar(5),@n_CmdCounter)        
                     PRINT 'sub full text : '  + @c_SubFullText        
                     PRINT 'fulltext : ' + @c_Fulltext        
                     PRINT 'Commander : ' +  @c_BartenderCommand --+ @c_NewLineChar + @c_GetFulltext        
                     PRINT 'commander scripts : ' + @c_BartenderFCommand        
                     print '11'        
                  END        
        
                  IF @b_debug='5'        
                  BEGIN        
                     SELECT 'Loop 1 ','@n_CmdCounter',@n_CmdCounter,'@n_CntBarRec',@n_CntBarRec        
                  END        
        
                  SET @c_GetFulltext = @c_SubFullText        
                  SET @c_BartenderCommand =  @c_GetFulltext        
                  SET @c_BartenderFCommand = @c_BartenderHCommand + @c_NewLineChar + @c_BartenderCommand        
        
                  IF @b_debug='5'        
                  BEGIN        
                     PRINT 'loop with ID : ' + convert(nvarchar(5),@n_CmdCounter) + ' and @n_CntBarRec : '+ convert(nvarchar(5),@n_CntBarRec)        
                     PRINT 'sub full text ' + @c_GetFulltext        
                     PRINT 'Full Text : ' + @c_FullText        
                  END        
                  IF @n_CmdCounter = @n_CntBarRec --AND @n_StartCNT = @n_CntPBatch  --CS27        
                  BEGIN        
                     IF @b_debug='6'        
                     BEGIN        
                        PRINT 'Set Last Record : '        
                        PRINT 'last Full Text : ' + @c_FullText        
                        SELECT 'last record 1','@n_CmdCounter',@n_CmdCounter,'@n_CntBarRec',@n_CntBarRec        
                     END        
                     SET @c_LastRec = 'Y'        
                     SET @n_CNTBatchRec = @n_CNTBatchRec + 1        
                     GOTO SEND_TCP_SOCKET        
                  END        
        
                  IF @b_debug='7'  and  @n_CmdCounter>=29        
                  BEGIN        
                     PRINT 'sub full text : '  + @c_SubFullText        
                     PRINT 'fulltext : ' + @c_GetFulltext        
                     PRINT 'Commander : ' +  @c_BartenderCommand --+ @c_NewLineChar + @c_GetFulltext        
                     PRINT 'commander scripts : ' + @c_BartenderFCommand        
                     print '2'        
                  END        
                  SET @n_CNTBatchRec = @n_CNTBatchRec + 1        
               END        
               /*CS31 Start*/        
            END        
            ELSE        
            BEGIN        
               --PRINT 'Print by single order'        
               SET @c_GetFulltext = @c_SubFullText        
               SET @c_BartenderCommand =  @c_GetFulltext        
               SET @c_BartenderFCommand = @c_BartenderHCommand + @c_NewLineChar + @c_BartenderCommand        
        
               IF @n_CmdCounter = @n_CntBarRec        
               BEGIN        
                  IF @b_debug='8'        
                  BEGIN        
                     PRINT 'Set Last Record : '        
                     PRINT 'last Full Text : ' + @c_FullText        
                     SELECT 'last record 1','@n_CmdCounter',@n_CmdCounter,'@n_CntBarRec',@n_CntBarRec        
                  END        
                  SET @c_LastRec = 'Y'        
                  SET @n_CNTBatchRec = @n_CNTBatchRec + 1        
               END        
               GOTO SEND_TCP_SOCKET        
            END        
            BACK_FROM_SEND_TCP_SOCKET:        
         END --cnt<>0        
        
         FETCH NEXT FROM CUR_BartenderCommandLoop        
         INTO @n_CmdCounter,@c_BT_Parm01, @c_BT_Parm02, @c_BT_Parm03,        
              @c_BT_Parm04, @c_BT_Parm05, @c_BT_Parm06,        
              @c_BT_Parm07, @c_BT_Parm08, @c_BT_Parm09,        
              @c_BT_Parm10, @c_KEY01, @c_KEY02,        
              @c_KEY03, @c_KEY04, @c_KEY05--,@n_Batch        
      END --WHILE @@FETCH_STATUS <> -1        
      CLOSE CUR_BartenderCommandLoop        
      DEALLOCATE CUR_BartenderCommandLoop        
        
      SET @n_StartCNT = @n_StartCNT + 1        
      SET @c_LastRec  ='N'              --CS32a        
   END   --WHILE @n_StartCNT        
        
   IF @b_debug = '3'        
   BEGIN        
      SELECT 'Go Quit ','@n_StartCNT',@n_StartCNT,'@n_CntPBatch',@n_CntPBatch        
   END        
   GOTO QUIT        
        
SEND_TCP_SOCKET:        
   BEGIN --(CS23)        
   IF @b_debug='8'        
   BEGIN        
      PRINT 'Check last record ' + @c_LastRec        
      PRINT 'Commander Trigger ' + @c_BartenderFCommand        
      PRINT 'Full Text 12345: ' + @c_fulltext        
   END        
        
   IF @b_debug = '1'        
   BEGIN        
      SELECT ' Commander Trigger ' , @c_BartenderFCommand        
   END        
        
   SET @c_DPC_MessageNo = 'C' + '000000000' --+ @c_MessageNum_Out        
   IF @b_debug ='9'        
   BEGIN        
      PRINT 'IN TCP Socket'        
      PRINT @c_BartenderFCommand        
   END        
        
   SET @n_Trace_NoOfLabel = @n_Trace_NoOfLabel + 1        
        
   IF ISNULL(@c_BartenderFCommand,'') <> ''        
   BEGIN    --ISNULL(@c_BartenderCommand,'') <> ''        
      IF @b_debug = '5'        
      BEGIN        
         SELECT ' result ' + @c_BartenderFCommand        
      END        
        
     /*CS21 start*/        
      IF LEN(@c_col02)>20        
      BEGIN        
         SET @c_col02 = substring(@c_col02,1,20)        
      END        
     /*CS21 End*/        
        
      SET @c_vbErrMsg = ''        
      SET @c_ReceiveMessage = ''        
      SET @c_LocalEndPoint = ''        
        
      IF @c_ZPLPRINT = '0'    --CS42        
      BEGIN  
         IF @n_JobID > 0 AND @c_Parm10 = 'B'                                        --(Wan01)
         BEGIN
            INSERT INTO rdt.rdtprintjob_Log
                              (JobName, ReportID, JobStatus, Datawindow, NoOfParms
                              ,Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10
                              ,Parm11, Parm12, Parm13, Parm14, Parm15, Parm16, Parm17, Parm18, Parm19, Parm20         
                              ,ReportLineNo                                                                           
                              ,Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, Storerkey, Function_ID
                              ,PDFPreview 
                              ,PaperSizeWxH, DCropWidth, DCropHeight, IsLandScape, IsColor, IsDuplex, IsCollate                                                                             
                              )
            SELECT JobName + '_' + CONVERT(VARCHAR(5),@n_Batch), ReportID, '9', Datawindow, NoOfParms
                  ,Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10
                  ,Parm11, Parm12, Parm13, Parm14, Parm15, Parm16, Parm17, Parm18, Parm19, Parm20                     
                  ,ReportLineNo                                                                                       
                  ,@cPrinterID, NoOfCopy, Mobile, TargetDB, @c_BartenderFCommand, JobType, Storerkey, Function_ID
                  ,PDFPreview 
                  ,PaperSizeWxH, DCropWidth, DCropHeight, IsLandScape, IsColor, IsDuplex, IsCollate                                                                                                    --(Wan09)
            FROM rdt.RDTPrintJob AS rpj WITH (NOLOCK)
            WHERE rpj.JobId = @n_JobID
            SET @n_JobID = SCOPE_IDENTITY() 
         END
         ELSE IF @n_JobID > 0 
         BEGIN
            DELETE FROM @t_PrintJob;
            IF EXISTS (SELECT 1 FROM rdt.RDTPrintJob AS rpj WITH (NOLOCK) WHERE rpj.JobId = @n_JobID)
            BEGIN
               UPDATE rdt.RDTPrintJob WITH (ROWLOCK)
                  SET PrintData = @c_BartenderFCommand
                     ,Printer   = @cPrinterID  
                     ,EditWho   = SUSER_SNAME()
                     ,EditDate  = GETDATE()
               OUTPUT Deleted.JobType INTO @t_PrintJob 
               WHERE JobID = @n_JobID
            END
            ELSE
            IF EXISTS (SELECT 1 FROM rdt.RDTPrintJob_Log AS rpjl WITH (NOLOCK) WHERE rpjl.JobId = @n_JobID)
            BEGIN
               UPDATE rdt.RDTPrintJob_Log WITH (ROWLOCK)
                  SET PrintData = @c_BartenderFCommand
                     ,Printer   = @cPrinterID 
                     ,EditWho   = SUSER_SNAME()
                     ,EditDate  = GETDATE()
               OUTPUT Deleted.JobType INTO @t_PrintJob       
               WHERE JobID = @n_JobID
            END
         END
         SET @n_SerialNo_Out = @n_JobID                                     
         SET @c_BatchNo = CASE WHEN LEN(@c_col01)<=30 
                               THEN (@c_col01 + RIGHT('0000'+CAST(@n_Batch AS VARCHAR(4)),4) 
                                              + RIGHT('00'+CAST(@n_CNTBatchRec-1 AS VARCHAR(2)),2)        
                                              + RIGHT('000'+CAST(ISNULL(@c_StartRec,'000') AS VARCHAR(3)),3)
                                              + RIGHT('000'+CAST(ISNULL(@c_EndRec,'000') AS VARCHAR(3)),3))        
                               ELSE '' END
         IF @n_PrintOverInternet = 1
         BEGIN
            SET @n_POS = CHARINDEX(':', @c_RemoteEndPoint,1)
   
            IF @n_POS > 0
            BEGIN
               SET @c_IP   = RTRIM(SUBSTRING(@c_RemoteEndPoint, 1, @n_POS - 1))
               SET @c_Port = LTRIM(SUBSTRING(@c_RemoteEndPoint, @n_POS + 1, LEN(@c_RemoteEndPoint)- @n_POS))
            END 
            SELECT TOP 1 @c_JobType = tpj.JobType FROM @t_PrintJob AS tpj
            
            EXEC dbo.isp_SubmitPrintJobToCloudPrint
               @c_DataProcess    = 'CloudPrint'
            ,  @c_Storerkey      = @c_Storerkey   
            ,  @c_PrintType      = @c_JobType
            ,  @c_PrinterName    = @c_PrinterName
            ,  @c_IP             = @c_IP
            ,  @c_Port           = @c_Port
            ,  @c_Data           = @c_BartenderFCommand
            ,  @c_DocumentType   = ''
            ,  @c_DocumentId     = @c_BatchNo            
            ,  @c_JobID          = @n_JobID
            ,  @b_Success        = @b_Success      OUTPUT  
            ,  @n_Err            = @n_Err          OUTPUT  
            ,  @c_ErrMsg         = @c_ErrMsg       OUTPUT  
         END
         ELSE
         BEGIN      
            BEGIN TRY --CS336        
               EXEC [master].[dbo].[isp_GenericTCPSocketClient]        
                    @c_IniFilePath        
                   ,@c_RemoteEndPoint        
                   ,@c_BartenderFCommand        
                   ,@c_LocalEndPoint OUTPUT        
                   ,@c_ReceiveMessage OUTPUT        
                   ,@c_vbErrMsg OUTPUT        
            END TRY        
            BEGIN CATCH        
              IF @c_vbErrMsg IS NULL        
                  SET @c_vbErrMsg = LEFT( ISNULL( ERROR_MESSAGE(), ''), 256)        
            END CATCH        
        
            SET @c_vbErrMsg = ISNULL( @c_vbErrMsg, '')        
            SET @c_LocalEndPoint = ISNULL(@c_LocalEndPoint,'')        
            SET @c_ReceiveMessage=ISNULL(@c_ReceiveMessage ,'')        
        
            SET @d_step3 = GETDATE() - @d_step3        -- (CS35)        
            SET @d_step4 = GETDATE()                   -- (CS35)        
        
            SET @d_step4 = GETDATE() - @d_step4         -- (CS35)  @c_TCPstatus        
        
            If @b_debug ='9'        
            BEGIN        
               PRINT 'IN TCP Socket'        
               PRINT @c_BartenderFCommand        
               SELECT @c_vbErrMsg '@c_vbErrMsg',@c_LocalEndPoint '@c_LocalEndPoint'        
            END        

            IF ISNULL(RTRIM(@c_vbErrMsg) ,'') = ''    --CS36 start        
            BEGIN        
               INSERT INTO TCPSocket_OUTLog        
              (        
                MessageNum   ,MessageType ,[Application]        
               ,DATA         ,STATUS      ,StorerKey        
               ,LabelNo      ,BatchNo     ,RemoteEndPoint        
               ,Refno,AddDate ,LocalEndPoint ,ErrMsg                   --(CS20)   --(CS26)        
              )        
               VALUES        
               (        
                 @c_DPC_MessageNo        
               ,'SEND'        
               ,'BARTENDER'        
               ,substring(@c_BartenderFCommand,1,4000)        
               ,'9'  --(SHONG02)        
               ,@c_StorerKey        
               ,''        
               --CS41 START        
               ,substring(CASE WHEN LEN(@c_col01)<=30 THEN (@c_col01 + RIGHT('0000'+CAST(@n_Batch AS VARCHAR(4)),4) + RIGHT('00'+CAST(@n_CNTBatchRec-1 AS VARCHAR(2)),2)        
                  + RIGHT('000'+CAST(ISNULL(@c_StartRec,'000') AS VARCHAR(3)),3)+ RIGHT('000'+CAST(ISNULL(@c_EndRec,'000') AS VARCHAR(3)),3))        
                  ELSE '' END, 1, 50) --CS36 END  --CS41 END        
               ,@c_RemoteEndPoint        
               ,'',@d_Trace_StartTime        
               ,@c_LocalEndPoint        
               ,@c_ReceiveMessage        
               )        
        
               SET @n_SerialNo_Out = @@IDENTITY        
            END        
            ELSE        
            BEGIN        
               INSERT INTO TCPSocket_OUTLog        
                       (        
                         MessageNum   ,MessageType ,[Application]        
                        ,DATA         ,STATUS      ,StorerKey        
                        ,LabelNo      ,BatchNo     ,RemoteEndPoint        
                        ,ErrMsg       ,Adddate     ,LocalEndPoint     --(CS26)        
                       )        
                      VALUES        
                       (        
                         @c_DPC_MessageNo    ,'SEND'              ,'BARTENDER'        
                        ,@cSQL               ,'5'                 ,@c_StorerKey        
                        ,''                  ,''                  ,@c_RemoteEndPoint        
                        ,@c_vbErrMsg         ,@d_Trace_StartTime  ,@c_LocalEndPoint                    --(CS26)        
                       )        
               SET @b_Success = 0        
               SET @n_Err = 80453        
               SET @c_ErrMsg = @c_vbErrMsg        
            END  
         END 

         IF @b_Debug = '1'        
         BEGIN        
            SELECT @n_SerialNo_Out '@n_SerialNo_Out'        
            PRINT @c_RemoteEndPoint        
         END 
                   
         IF @n_SerialNo_Out > 0                          --(Wan01) - START
         BEGIN
            IF @c_Parm10 = 'B'    --CS36 start        
            BEGIN        
               UPDATE @PrintLog        
               SET serialno = @n_SerialNo_Out        
               WHERE NEXTRow = 'N'        
        
               INSERT INTO BartenderPrinterLog (serialno,rowid,field01,field02,field03,logdate)        
               SELECT serialno,rowid,field01,field02,field03,logdate        
               FROM @PrintLog        
               WHERE NEXTRow = 'N'        
        
               DELETE @PrintLog WHERE serialno = @n_SerialNo_Out        
        
               UPDATE @PrintLog        
               SET NextRow ='N'        
        
               IF @b_Debug = '3'        
               BEGIN        
                  SELECT 'Delete  @PrintLog '        
                  SELECT * FROM @PrintLog        
               END        
            END       --CS36               
        
            IF @b_Debug='3'        
            BEGIN        
               SELECT * FROM #Result AS r        
            END        
            DELETE FROM #Result  --INC0069041 
         END                                   
      END                                          --(Wan01) - END       
        
      IF @b_Debug = '1'        
      BEGIN        
         PRINT convert(nvarchar(20),getdate(),120)        
      END        
        
      IF @b_Debug = '1'        
      BEGIN        
          PRINT 'Err return ' + @c_result        
      END        
        
      IF @c_Returnresult = 'Y'        
      BEGIN  --@c_Returnresult = 'Y'        
         IF ISNULL(@c_result ,'') = ''        
         BEGIN  --@c_result = ''        
            SET @n_err=0        
            SET @c_result = 'No Error'        
            SET @c_errmsg = 'No Error'        
            SELECT @n_err,@c_result,@c_errmsg AS c_Result        
         END        
      END  ----@c_Returnresult = 'Y'        
        
      WHILE @@TRANCOUNT > 0        
      COMMIT TRAN        
 
      SET @c_counter = @c_counter + 1        
        
      IF @c_Returnresult = 'Y'        
      BEGIN        
         IF ISNULL(@c_result ,'') = ''        
         BEGIN        
            SELECT @n_err = 25013        
            SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': No Record for label type  : ' + @c_LabelType + ' (isp_BT_GenBartenderCommand) '        
            SET @c_result = @c_errmsg        
            SELECT (convert(nvarchar(5),@n_err) + @c_result + @c_errmsg) AS c_Result --(CS14)        
         END        
      END        
        
      IF @n_err <> 0 AND @n_PrintOverInternet = 0                                   --(Wan01)     
      BEGIN        
         SET @c_DPC_MessageNo = 'C' + '000000000' --+ @c_MessageNum_Out        
         SET @c_result = @c_errmsg        
        
         INSERT INTO TCPSocket_OUTLog        
         (        
             MessageNum   ,MessageType ,[Application]        
            ,DATA         ,STATUS      ,StorerKey        
            ,LabelNo      ,BatchNo     ,RemoteEndPoint        
            ,ErrMsg       ,Adddate     --(CS26)        
         )        
         VALUES        
         (        
            @c_DPC_MessageNo  ,'SEND'     ,'BARTENDER'        
            ,@cSQL             ,'5'        ,@c_StorerKey        
            ,''                ,''         ,@c_RemoteEndPoint        
            ,@c_result,        @d_Trace_StartTime        
         )        
      END  -- End log into TCP_LOG for RDT        
        
      SET @c_Trace_Step1 = ISNULL(@c_userid, SUSER_SNAME() )        
      SET @c_Trace_Step2 = ISNULL(CAST(@n_Trace_NoOfLabel AS VARCHAR(10)), '')        
      SET @d_Trace_EndTime = GETDATE()        
      SET @c_UserName = SUSER_SNAME()        
        
      IF @c_logfile = 'Y' AND @c_Parm10 <> 'B'    --CS36        
      BEGIN        
         SET @d_step1 = NULL        
         SET @d_step2 = NULL        
         SET @d_step3 = NULL        
         SET @d_step4 = NULL        
         SET @d_step5 = NULL         
      END        
      /*CS35 END*/        
        
      SET @c_BartenderFCommand = ''        
      SET @n_Batch = @n_Batch + 1         --(CS23)        
      SET @n_CNTBatchRec = 1     --(CS23)        
        
      /*CS29a*/        
      IF @c_Parm10 = 'B'   --CS36        
      BEGIN        
         SELECT @n_CntPrnLogTBL = Count(1)        
         FROM @Printlog        
      END        
        
      /*CS33 Start*/        
      IF @c_LastRec <> 'Y'        
      BEGIN        
         GOTO BACK_FROM_SEND_TCP_SOCKET        
      END        
      ELSE        
      BEGIN        
         IF @n_StartCNT = @n_CntPBatch  AND @n_CntPrnLogTBL = 0 --CS27        
         BEGIN        
            IF @b_debug='9'        
            BEGIN        
               SELECT * from @Printlog        
               PRINT 'Quit'        
               PRINT 'last record flag : ' + @c_LastRec        
               PRINT '@n_StartCNT' + convert(nvarchar(5),@n_StartCNT) + ',@n_CntPBatch' + convert(nvarchar(5),@n_CntPBatch)                  
            END        
            GOTO QUIT        
         END        
         ELSE        
         BEGIN        
            GOTO BACK_FROM_SEND_TCP_SOCKET        
         END        
      END        
   END    -- END @c_ZPLPRINT = 'N'        
   ELSE   --CS42 START        
   BEGIN        
      GOTO QUIT        
   END  --CS42 END        
   END --(CS23)        
QUIT:        
        
   IF @c_Returnresult = 'Y'        
   BEGIN        
      IF ISNULL(@c_result ,'') = ''        
      BEGIN        
        SELECT @n_err = 25023        
        SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': No Record for label type  : ' + @c_LabelType + ' (isp_BT_GenBartenderCommand) '        
        SET @c_result = @c_errmsg        
        SELECT (convert(nvarchar(5),@n_err) + @c_result + @c_errmsg) AS c_Result --(CS14)        
      END        
   END        
        
   IF @n_err <> 0        
   BEGIN        
      SET @c_DPC_MessageNo = 'C' + '000000000' --+ @c_MessageNum_Out        
      SET @c_result = @c_errmsg        
        
      INSERT INTO TCPSocket_OUTLog        
      (        
         MessageNum   ,MessageType ,[Application]        
         ,DATA         ,STATUS      ,StorerKey        
         ,LabelNo      ,BatchNo     ,RemoteEndPoint,        
         ErrMsg        , AddDate        --(CS26)        
      )        
      VALUES        
      (        
         @c_DPC_MessageNo   ,'SEND'   ,'BARTENDER'        
         ,@cSQL              ,'5'      ,@c_StorerKey        
         ,''                 ,''       ,@c_RemoteEndPoint        
         ,@c_result          ,@d_Trace_StartTime        
      )         
        
     /*CS37 Start*/        
      IF @n_IsRDT = '1'        
      BEGIN        
         RAISERROR (@n_err, 10, 1) WITH SETERROR        
      END        
       /*CS37 END*/        
   END      
      
   --CS42 START        
   IF @c_ZPLPRINT = '1'        
   BEGIN    
      IF @b_debug='5'    
      BEGIN    
         SELECT * FROM @RESULTZPL        
      END    
             
      SELECT * FROM @RESULTZPL        
   END        
  --CS42 END         
        
   WHILE @@TRANCOUNT < @n_StartTrnCnt        
   BEGIN TRAN        
END 

GO