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
/* 2013-11-19 9.0  CSCHONG    Write to File  (CS08)                           */ 
/* 2016-11-13 9.1  SHONG      No Update TCPSOCKET_OUTLOG if socket send OK    */
/******************************************************************************/       
                   
CREATE PROC [dbo].[isp_BT_GenBartenderCommanderScript](          
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
     ,@c_NoCopy       CHAR(1)                     --CS02   
     ,@b_Debug        CHAR(1)=0  
     ,@c_Returnresult NCHAR(1)='N'                --CS04
     ,@n_err          INT = 0             OUTPUT      --CS01  
     ,@c_errmsg       NVARCHAR(250)=''   OUTPUT      --CS01 
     
  )              
AS              
BEGIN 
   SET NOCOUNT ON
             
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
     -- [ID]    [INT] IDENTITY(1,1) NOT NULL,                      
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
          ,@c_PrintJobName  NVARCHAR(250)      
          ,@c_PrinterName   NVARCHAR(150)   
          ,@c_CopyPrint     NVARCHAR(100)    --CS02     
          ,@c_Copy          NVARCHAR(2)      --CS02  
          ,@c_Result        NVARCHAR(200)    --CS04
          ,@c_GetUserID     NVARCHAR(18)      --CS06
          ,@n_CntUser       INT               --CS06
          ,@n_StartTrnCnt   INT
         
         
   
   SET @n_StartTrnCnt = @@TRANCOUNT           
   
   DECLARE @c_BartenderCommand  NVARCHAR(2000)          
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
          ,@c_BT_Parm06     NVARCHAR(60)          
          ,@c_BT_Parm07         NVARCHAR(60)          
          ,@c_BT_Parm08         NVARCHAR(60)          
          ,@c_BT_Parm09         NVARCHAR(60)          
          ,@c_BT_Parm10         NVARCHAR(60)   
          ,@c_tempfilepath      NVARCHAR(215)   --CS08
          ,@c_FullText          NVARCHAR(4000)   --CS08    
          ,@c_Filename          NVARCHAR(100)   --CS08
          ,@n_WorkFolderExists  INT             --CS08   
          ,@c_WorkFilePath      NVARCHAR(215)   --CS08
          ,@c_SqlString         NVARCHAR(2000)  --CS08
          ,@c_NewLineChar       CHAR(2)         --CS08
          ,@c_GetFullText       NVARCHAR(4000)  --CS08 
          ,@n_cnt               INT 
 
    

   DECLARE @d_Trace_StartTime  DATETIME, 
           @d_Trace_EndTime    DATETIME,
           @n_Trace_NoOfLabel  INT, 
           @d_Trace_Step1      DATETIME, 
           @c_Trace_Step1      NVARCHAR(20),
           @c_Trace_Step2      NVARCHAR(20), 
           @c_UserName         NVARCHAR(20)

  Declare  @c_Col01  NVARCHAR (80),
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
              ' (isp_BT_GenBartenderCommand) '
       
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
            + ' with username ' + @c_userID +  ' (isp_BT_GenBartenderCommand) '    
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
       ,@Parm10 nvarchar(60)'          
       ,@c_Parm01, @c_Parm02 ,@c_Parm03          
       ,@c_Parm04, @c_Parm05 ,@c_Parm06          
       ,@c_Parm07, @c_Parm08 ,@c_Parm09          
       ,@c_Parm10                 

   SET @d_Trace_Step1 = GETDATE()

             
   DECLARE CUR_BartenderCommandLoop CURSOR LOCAL FAST_FORWARD READ_ONLY           
   FOR          
       SELECT TOP 13 PARM01  ,PARM02 ,PARM03          
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
      INTO @c_BT_Parm01, @c_BT_Parm02, @c_BT_Parm03,           
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
        SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': Label template path not setup for label type  : ' + @c_LabelType + ' (isp_BT_GenBartenderCommand) '    
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
         SELECT @c_errmsg = ' NSQL ' + CONVERT(CHAR(5),@n_err) + ': sub SP not setup for label type  : ' + @c_LabelType + ' (isp_BT_GenBartenderCommand) '    
         SET @c_result = @c_errmsg        --CS04
        
         IF @c_Returnresult = 'Y'
         BEGIN
            SELECT @c_result as c_Result
         END
         GOTO QUIT      
     END   
     
  
     /*CS01 End*/     

--        IF SUBSTRING(@c_tempfilepath, LEN(@c_tempfilepath), 1) <> '\'
--        BEGIN
--        SET @c_tempfilepath = @c_tempfilepath + '\'
--        END

        --SET @c_WorkFilePath = @c_tempfilepath 


        --SET @n_WorkFolderExists = 1
        SET @c_SqlString = N' Exec ' + @c_SubSP + ' @Parm01,@Parm02 ,@Parm03,@Parm04,@Parm05,@Parm06,@Parm07,@Parm08,@Parm09,@Parm10'

        IF @b_debug = '1'
        BEGIN
        Print @c_SqlString
       -- Print 'parm01 : ' + @c_BT_Parm01 + ' param02 : ' + @c_BT_Parm02 + ' param03: ' + @c_BT_Parm03 + ' param04 : ' + @c_BT_Parm04  
        END
       
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
                
      /* ,@Parm01 = @c_Parm01  ,@Parm02 = @c_Parm02 , @Parm03 = @c_Parm03              
       ,@Parm04 = @c_Parm04  ,@Parm05 = @c_Parm05 , @Parm06 = @c_Parm06              
       ,@Parm07 = @c_Parm07  ,@Parm08 = @c_Parm08 , @Parm09 = @c_Parm09               
       ,@Parm10 = @c_Parm10 */
         

        SET @d_Trace_Step1 = GETDATE()
 
     -- DECLARE CUR_BartenderLoop CURSOR LOCAL FAST_FORWARD READ_ONLY           
     -- FOR   
       SELECT @n_cnt = count(1) FROM  #Result      
       SET @c_Fulltext = ''       

       IF @n_cnt <> 0
       BEGIN
       SELECT @c_col01=ISNULL(col01,''),@c_col02=ISNULL(col02,''),
              @c_col03=ISNULL(col03,''),@c_col04=ISNULL(col04,''),
              @c_col05=ISNULL(col05,''),@c_col06=ISNULL(col06,''),
              @c_col07=ISNULL(col07,''),@c_col08=ISNULL(col08,''),
              @c_col09=ISNULL(col09,''),@c_col10=ISNULL(col10,''),
              @c_col11=ISNULL(col11,''),@c_col12=ISNULL(col12,''),
              @c_col13=ISNULL(col13,''),@c_col14=ISNULL(col14,''),
              @c_col15=ISNULL(col15,''),@c_col16=ISNULL(col16,''),
              @c_col17=ISNULL(col17,''),@c_col18=ISNULL(col18,''),
              @c_col19=ISNULL(col19,''),@c_col20=ISNULL(col20,''),
              @c_col21=ISNULL(col21,''),@c_col22=ISNULL(col22,''),
              @c_col23=ISNULL(col23,''),@c_col24=ISNULL(col24,''),
              @c_col25=ISNULL(col25,''),@c_col26=ISNULL(col26,''),
              @c_col27=ISNULL(col27,''),@c_col28=ISNULL(col28,''),
              @c_col29=ISNULL(col29,''),@c_col30=ISNULL(col30,''),
              @c_col31=ISNULL(col31,''),@c_col32=ISNULL(col32,''),
              @c_col33=ISNULL(col33,''),@c_col34=ISNULL(col34,''),
              @c_col35=ISNULL(col35,''),@c_col36=ISNULL(col36,''),
              @c_col37=ISNULL(col37,''),@c_col38=ISNULL(col38,''),
              @c_col39=ISNULL(col39,''),@c_col40=ISNULL(col40,''),
              @c_col41=ISNULL(col41,''),@c_col42=ISNULL(col42,''),
              @c_col43=ISNULL(col43,''),@c_col44=ISNULL(col44,''),
              @c_col45=ISNULL(col45,''),@c_col46=ISNULL(col46,''),
              @c_col47=ISNULL(col47,''),@c_col48=ISNULL(col48,''),
              @c_col49=ISNULL(col49,''),@c_col50=ISNULL(col50,''),
              @c_col51=ISNULL(col51,''),@c_col52=ISNULL(col52,''),
              @c_col53=ISNULL(col53,''),@c_col54=ISNULL(col54,''),
              @c_col55=ISNULL(col55,''),@c_col56=ISNULL(col56,''),
              @c_col57=ISNULL(col57,''),@c_col58=ISNULL(col58,''),
              @c_col59=ISNULL(col59,''),@c_col60=ISNULL(col60,'')
              FROM   #Result   

        IF @b_debug='1'
           BEGIN
           SELECT 'Check'
           SELECT * FROM #Result
           END        
             
      -- OPEN CUR_BartenderLoop           
       
--       FETCH NEXT FROM CUR_BartenderLoop 
--       INTO @c_col01, @c_col02, @c_col03, @c_col04, @c_col05, 
--            @c_col06, @c_col07, @c_col08, @c_col09, @c_col10, 
--            @c_col11, @c_col12, @c_col13, @c_col14, @c_col15, 
--            @c_col16, @c_col17, @c_col18, @c_col19, @c_col20,
--            @c_col21, @c_col22, @c_col23, @c_col24, @c_col25, 
--            @c_col26, @c_col27, @c_col28, @c_col29, @c_col30, 
--            @c_col31, @c_col32, @c_col33, @c_col34, @c_col35, 
--            @c_col36, @c_col37, @c_col38, @c_col39, @c_col40,  
--            @c_col41, @c_col42, @c_col43, @c_col44, @c_col45, 
--            @c_col46, @c_col47, @c_col48, @c_col49, @c_col50, 
--            @c_col51, @c_col52, @c_col53, @c_col54, @c_col55, 
--            @c_col56, @c_col57, @c_col58, @c_col59, @c_col60 
--
--
--       WHILE @@FETCH_STATUS <> -1          
--       BEGIN  
       
       SET @c_Fulltext = '"' + LTRIM(RTRIM(@c_col01)) + '"'             
                       +',"' + LTRIM(RTRIM(@c_col02)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col03)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col04)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col05)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col06)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col07)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col08)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col09)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col10)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col11)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col12)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col13)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col14)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col15)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col16)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col17)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col18)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col19)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col20)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col21)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col22)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col23)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col24)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col25)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col26)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col27)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col28)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col29)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col30)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col31)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col32)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col33)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col34)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col35)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col36)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col37)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col38)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col39)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col40)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col41)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col42)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col43)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col44)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col45)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col46)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col47)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col48)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col49)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col50)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col51)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col52)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col53)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col54)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col55)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col56)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col57)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col58)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col59)) + '"'
                       +',"' + LTRIM(RTRIM(@c_col60)) + '"'

           IF @b_debug='1'
           BEGIN
           PRINT ' Full text : ' + @c_Fulltext
           END
           
           SET @c_PrintJobName = ''

           IF ISNULL(@c_TemplatePath ,'') <> '' and ISNULL(@c_tempfilepath,'') <> ''      
           BEGIN          
            SET @c_PrintJobName = ISNULL(RTRIM(@c_userid),'') + ISNULL(RTRIM(@c_Printername),'') + RTRIM(@c_LabelType) + convert(varchar(8),getdate(),112)+convert(varchar(10),getdate(),114)  
               
              IF @b_Debug ='1'      
              BEGIN      
                 PRINT ' Print job name is :  ' + @c_Printername + ' with No of copy is : ' + @c_CopyPrint  
              END  
          END   

          SET @c_Filename = REPLACE(@c_PrintJobName,':','') + '.csv'
      -- SET @c_Filename = REPLACE(@c_PrintJobName,':','') + '.txt'         
           
           SET @c_BartenderCommand = '%BTW% /AF="' + @c_TemplatePath + '" /PRN="' + @c_Printername +          
               '" /PrintJobName="' + REPLACE(@c_PrintJobName,':','') + '" /R=3 /' + @c_CopyPrint + ' /P /D="%Trigger File Name%" '              
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand) + @c_NewLineChar +  '%END%'
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand) + @c_NewLineChar +  @c_Fulltext          
          /* SET @c_BartenderCommand = RTRIM(@c_BartenderCommand)           
               + CASE           
                      WHEN ISNULL(@c_SubSP ,'') <> '' THEN ' /?GetSP="' + @c_SubSP + '"'          
                      ELSE ' /?GetSP="" '          
                 END          
                     
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand)           
               + CASE           
                      WHEN ISNULL(@c_BT_Parm01 ,'') <> '' THEN ' ?GetParm1="' + @c_BT_Parm01 + '"'          
                      ELSE ' ?GetParm1=" " '          
                 END          
                     
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand)           
               + CASE           
                      WHEN ISNULL(@c_BT_Parm02 ,'') <> '' THEN ' ?GetParm2="' + @c_BT_Parm02 + '"'          
                      ELSE ' ?GetParm2=" " '          
                 END          
                  
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand)           
               + CASE           
                      WHEN ISNULL(@c_BT_Parm03 ,'') <> '' THEN ' ?GetParm3="' + @c_BT_Parm03 + '"'          
                      ELSE ' ?GetParm3=" " '          
                 END          
                     
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand)           
               + CASE           
                      WHEN ISNULL(@c_BT_Parm04 ,'') <> '' THEN ' ?GetParm4="' + @c_BT_Parm04 + '"'          
                      ELSE ' ?GetParm4=" " '          
                 END          
                     
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand)           
               + CASE           
                      WHEN ISNULL(@c_BT_Parm05 ,'') <> '' THEN ' ?GetParm5="' + @c_BT_Parm05 + '"'          
                      ELSE ' ?GetParm5=" " '          
                 END          
                     
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand)           
               + CASE           
                      WHEN ISNULL(@c_BT_Parm06 ,'') <> '' THEN ' ?GetParm6="' + @c_BT_Parm06 + '"'                         
                      ELSE ' ?GetParm6=" " '          
                 END          
                     
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand)           
               + CASE           
                      WHEN ISNULL(@c_BT_Parm07 ,'') <> '' THEN ' ?GetParm7="' + @c_BT_Parm07 + '"'          
                      ELSE ' ?GetParm7=" " '          
                 END          
                     
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand)           
               + CASE           
                      WHEN ISNULL(@c_BT_Parm08 ,'') <> '' THEN ' ?GetParm8="' + @c_BT_Parm08 + '"'          
                      ELSE ' ?GetParm8=" " '          
                 END          
                     
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand)           
               + CASE           
                      WHEN ISNULL(@c_BT_Parm09 ,'') <> '' THEN ' ?GetParm9="' + @c_BT_Parm09 + '"'          
                      ELSE ' ?GetParm9=" " '          
                 END          
                     
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand)           
               + CASE           
                      WHEN ISNULL(@c_BT_Parm10 ,'') <> '' THEN ' ?GetParm10="' + @c_BT_Parm10 + '"'          
                      ELSE ' ?GetParm10=" " '          
                 END              
                     
           SET @c_BartenderCommand = RTRIM(@c_BartenderCommand) + CHAR(13) + ' %END% '           
                 
           IF @b_Debug = '1'      
           BEGIN          
              PRINT @c_BartenderCommand      
           END    
       
      END    */

       /*Start write file start*/
       
         

       IF @b_debug = '1'
       BEGIN
       Print 'String output : ' + @c_BartenderCommand
       Print ' workfilepath ' + @c_WorkFilePath + ' with filename : ' + @c_Filename
       END

   /*     EXEC isp_WriteStringToFile
                  @c_BartenderCommand,
                  @c_WorkFilePath,
                  @c_Filename,
                  2, -- IOMode 2 = ForWriting ,8 = ForAppending
                  @b_success Output

            IF @b_success <> 1
            BEGIN
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60111
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Writing GSI XML/CSV file. (isp_PrintGS1Label)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               
               SET @c_result = @c_errmsg        
    
              IF @c_Returnresult = 'Y'
              BEGIN
                 SELECT @c_result as c_Result
              END
                
               GOTO QUIT      
            END    */

      /* Send to Bartender - Start */
      /*    EXECUTE nspg_GetKey           
      'TCPOUTLog',           
      9,           
      @c_MessageNum_Out OUTPUT,           
      @b_Success OUTPUT,           
      @n_Err OUTPUT,           
      @c_ErrMsg OUTPUT                            
                
      IF @b_Success = 1      */    
    --  BEGIN          
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
         ,'9'          
         ,''          
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
                                   
      IF ISNULL(RTRIM(@c_vbErrMsg) ,'') <> ''          
      BEGIN          
          SET @n_Status_Out = 5                    
                    
          UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)          
          SET    STATUS = CONVERT(VARCHAR(1) ,@n_Status_Out)          
                ,ErrMsg = ISNULL(@c_vbErrMsg ,'')          
                ,LocalEndPoint = @c_LocalEndPoint          
          WHERE  SerialNo = @n_SerialNo_Out                      
                    
          SET @b_Success = 0                    
          SET @n_Err = 80453                    
          SET @c_ErrMsg = @c_vbErrMsg          
      END            
                   
      IF ISNULL(RTRIM(@c_ReceiveMessage) ,'') <> ''          
      BEGIN          
          SET @n_Status_Out = 9                    
                    
          --UPDATE dbo.TCPSocket_OUTLog WITH (ROWLOCK)          
          --SET    STATUS         = CONVERT(VARCHAR(1) ,@n_Status_Out)                   
          --      ,LocalEndPoint  = @c_LocalEndPoint          
          --WHERE  SerialNo       = @n_SerialNo_Out          
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
              SET @c_result = 'No Error'
              SELECT @c_result AS c_Result
          END
      END      
    END  
      -- Purposely wait for 1 second

      WHILE @@TRANCOUNT > 0 
      COMMIT TRAN


     -- WAITFOR DELAY '00:00:01' 
      /* Send to Bartender - End */               
--      FETCH NEXT FROM CUR_BartenderLoop 
--       INTO @c_col01, @c_col02, @c_col03, @c_col04, @c_col05, 
--            @c_col06, @c_col07, @c_col08, @c_col09, @c_col10, 
--            @c_col11, @c_col12, @c_col13, @c_col14, @c_col15, 
--            @c_col16, @c_col17, @c_col18, @c_col19, @c_col20,
--            @c_col21, @c_col22, @c_col23, @c_col24, @c_col25, 
--            @c_col26, @c_col27, @c_col28, @c_col29, @c_col30, 
--            @c_col31, @c_col32, @c_col33, @c_col34, @c_col35, 
--            @c_col36, @c_col37, @c_col38, @c_col39, @c_col40,  
--            @c_col41, @c_col42, @c_col43, @c_col44, @c_col45, 
--            @c_col46, @c_col47, @c_col48, @c_col49, @c_col50, 
--            @c_col51, @c_col52, @c_col53, @c_col54, @c_col55, 
--            @c_col56, @c_col57, @c_col58, @c_col59, @c_col60       
--   END           
--   CLOSE CUR_BartenderLoop           
--   DEALLOCATE CUR_BartenderLoop 

   WAITFOR DELAY '00:00:01'  
   FETCH NEXT FROM CUR_BartenderCommandLoop 
   INTO @c_BT_Parm01, @c_BT_Parm02, @c_BT_Parm03,           
           @c_BT_Parm04, @c_BT_Parm05, @c_BT_Parm06,           
           @c_BT_Parm07, @c_BT_Parm08, @c_BT_Parm09,           
           @c_BT_Parm10, @c_KEY01, @c_KEY02,           
           @c_KEY03, @c_KEY04, @c_KEY05              
                     
   END           
   CLOSE CUR_BartenderCommandLoop           
   DEALLOCATE CUR_BartenderCommandLoop 

   SET @c_Trace_Step1 = ISNULL(@c_userid, SUSER_SNAME() ) -- CONVERT(VARCHAR(12),GETDATE() - @d_Trace_Step1 ,114)
   SET @c_Trace_Step2 = ISNULL(CAST(@n_Trace_NoOfLabel AS VARCHAR(10)), '') 
   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()
   
   EXEC isp_InsertTraceInfo 
      @c_TraceCode = 'BARTENDER',
      @c_TraceName = 'isp_BT_GenBartenderCommand',
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

GRANT EXECUTE ON [dbo].[isp_BT_GenBartenderCommanderScript] TO nsql

GO