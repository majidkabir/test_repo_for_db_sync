SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: WM.lsp_WM_Print_ItfDoc_Wrapper                          */
/* Creation Date: 2023-02-15                                            */
/* Copyright: Mearsk                                                    */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: NextGen Ecom Packing                                        */
/*        : LFWM-3913-Ship Reference Enhancement-Print Interface Document*/                                                         
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2023-02-15  Wan      1.0   Created & DevOps Combine Script           */ 
/* 2023-07-07  Wan01    1.1   PAC-15:Ecom Packing | Print Packing Report*/
/*                            - Backend                                 */
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_Print_ItfDoc_Wrapper]
   @n_WMReportRowID      BIGINT 
,  @c_Storerkey          NVARCHAR(15)
,  @c_Facility           NVARCHAR(5)
,  @c_UserName           NVARCHAR(128)  
,  @n_Noofcopy           INT            = 1                                                     
,  @c_PrinterID          NVARCHAR(30)   = ''
,  @c_IsPaperPrinter     NCHAR(1)       = 'Y'
,  @n_Noofparms          INT            = 0
,  @c_Parm1              NVARCHAR(60)
,  @c_Parm2              NVARCHAR(60)   = ''
,  @c_Parm3              NVARCHAR(60)   = ''
,  @c_Parm4              NVARCHAR(60)   = ''
,  @c_Parm5              NVARCHAR(60)   = ''
,  @c_Parm6              NVARCHAR(60)   = ''
,  @c_Parm7              NVARCHAR(60)   = ''
,  @c_Parm8              NVARCHAR(60)   = ''
,  @c_Parm9              NVARCHAR(60)   = ''
,  @c_Parm10             NVARCHAR(60)   = ''         
,  @c_Parm11             NVARCHAR(60)   = ''
,  @c_Parm12             NVARCHAR(60)   = ''
,  @c_Parm13             NVARCHAR(60)   = ''
,  @c_Parm14             NVARCHAR(60)   = ''
,  @c_Parm15             NVARCHAR(60)   = ''
,  @c_Parm16             NVARCHAR(60)   = ''
,  @c_Parm17             NVARCHAR(60)   = ''
,  @c_Parm18             NVARCHAR(60)   = ''
,  @c_Parm19             NVARCHAR(60)   = ''
,  @c_Parm20             NVARCHAR(60)   = ''
,  @b_Success            INT            = 1  OUTPUT
,  @n_Err                INT            = 0  OUTPUT
,  @c_ErrMsg             NVARCHAR(255)  = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                INT               = @@TRANCOUNT
         , @n_Continue                 INT               = 1
  
         , @b_ContinuePrint            BIT               = 1
         , @n_IsExists                 INT               = 0

         , @n_RowID                    INT               = 0
         , @n_Pos_Pctg                 INT               = 0
         
         , @c_MoveToArchive            NCHAR(1)          = '1'
         
         , @c_SourceType               NVARCHAR(50)      = 'lsp_WM_Print_ItfDoc_Wrapper'
         , @c_ReportID                 NVARCHAR(10)      = ''
         , @c_ReportLineNo             NVARCHAR(5)       = ''
         , @c_PrintType                NVARCHAR(30)      = ''
         , @c_PrintTemplateSP          NVARCHAR(1000)    = ''
         , @c_ReportTemplate           NVARCHAR(4000)    = ''
         
         , @c_PrintFileFolder          NVARCHAR(100)     = ''
         , @c_FileFolder               NVARCHAR(100)     = ''
         , @c_FileArchiveFolder        NVARCHAR(100)     = ''
         --, @c_SQL_Select               NVARCHAR(MAX)     = ''
               
         , @c_Authority                NVARCHAR(30)      = ''
         , @c_URL                      NVARCHAR(1000)    = ''
         , @c_URLHost                  NVARCHAR(200)     = ''
         , @c_URLPath                  NVARCHAR(200)     = '' 
         , @c_URLQuery                 NVARCHAR(200)     = ''                    
         , @c_ITFFile                  NVARCHAR(500)     = ''
         , @c_ITFFilePath              NVARCHAR(500)     = ''
         , @c_Encrypted                NVARCHAR(500)     = ''  
         , @c_FileFolderURL            NVARCHAR(500)     = '' 
         , @c_FileNameURL              NVARCHAR(500)     = ''   
         
         , @c_PrintData                NVARCHAR(MAX)     = ''
         , @c_PrintSettings            NVARCHAR(4000)    = ''
         , @c_StorerConfig             NVARCHAR(30)      = ''
         , @c_Reprint                  NCHAR(1)          = 'Y'
         
         , @c_SQL                      NVARCHAR(MAX)     = ''
         , @c_SQLParms                 NVARCHAR(MAX)     = ''    

   BEGIN TRY
      SELECT @c_ReportID               = w.ReportID
            ,@c_PrintType              = w.Printtype
            ,@c_PrintSettings          = w.PrintSettings
            ,@c_ReportLineNo           = w.ReportLineNo
            ,@c_ReportTemplate         = w.ReportTemplate               --SQL to Get Report ITFDOC FileName
            ,@c_PrintTemplateSP        = w.PrintTemplateSP
            ,@c_FileFolder             = w.FileFolder                   --Report Folder
            --,@c_SQL_Select             = w.SQL_Select                 
      FROM dbo.WMREPORTDETAIL AS w WITH (NOLOCK)
      WHERE w.RowID = @n_WMReportRowID
    
      SET @c_StorerConfig = ''
      SET @c_StorerConfig = dbo.fnc_GetParamValueFromString( '@c_StorerConfig', @c_PrintSettings, @c_StorerConfig)
         
      --IF @c_StorerConfig = ''
      --BEGIN
      --   GOTO EXIT_SP
      --END 
            
      SELECT @c_Authority = fgr.Authority FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', @c_StorerConfig) AS fgr
      IF @c_Authority = 1 AND @c_StorerConfig IN ('PrintItfReport')
      BEGIN
         EXEC dbo.isp_PrintInterface_Report 
            @c_Parm01   = @c_Parm1
         ,  @c_Parm02   = @c_Parm2
         ,  @c_Parm03   = @c_Parm3
         ,  @c_Parm04   = @c_Parm4
         ,  @c_Parm05   = @c_Parm5
         ,  @b_Success  = @b_Success   OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT       
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
         ,  @c_PrinterID= @c_PrinterID     

         IF @b_Success = 0 
         BEGIN
            SET @n_Continue = 3                 
            SET @n_err = 561101
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing isp_PrintInterface_Report. (lsp_WM_Print_ItfDoc_Wrapper)'
                           + '( ' + @c_errmsg + ' )'
            GOTO EXIT_SP
         END  
         SET @b_ContinuePrint = 0
      END
      
      SET @c_Reprint = 'Y'
      SET @c_StorerConfig = dbo.fnc_GetParamValueFromString( '@c_Reprint', @c_PrintSettings, @c_Reprint)

      IF @b_ContinuePrint = 1
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE id = OBJECT_ID(@c_Authority) AND TYPE = 'P')
         BEGIN
            SET @c_SQL = N'EXEC ' + @c_PrintTemplateSP
                       + ' @n_WMReportRowID  = @n_WMReportRowID' 
                       + ',@c_Storerkey      = @c_Storerkey'
                       + ',@c_Facility       = @c_Facility '
                       + ',@c_UserName       = @c_UserName '
                       + ',@n_Noofcopy       = @n_Noofcopy '
                       + ',@c_PrinterID      = @c_PrinterID'
                       + ',@c_IsPaperPrinter = @c_IsPaperPrinter'
                       + ',@n_Noofparms      = @n_Noofparms'
                       + ',@c_Parm1          = @c_Parm1'   
                       + ',@c_Parm2          = @c_Parm2'  
                       + ',@c_Parm3          = @c_Parm3'  
                       + ',@c_Parm4          = @c_Parm4'  
                       + ',@c_Parm5          = @c_Parm5'  
                       + ',@c_Parm6          = @c_Parm6'  
                       + ',@c_Parm7          = @c_Parm7'  
                       + ',@c_Parm8          = @c_Parm8'  
                       + ',@c_Parm9          = @c_Parm9'  
                       + ',@c_Parm10         = @c_Parm10'   
                       + ',@c_Parm11         = @c_Parm11'   
                       + ',@c_Parm12         = @c_Parm12'   
                       + ',@c_Parm13         = @c_Parm13'   
                       + ',@c_Parm14         = @c_Parm14'   
                       + ',@c_Parm15         = @c_Parm15'   
                       + ',@c_Parm16         = @c_Parm16'   
                       + ',@c_Parm17         = @c_Parm17'   
                       + ',@c_Parm18         = @c_Parm18'   
                       + ',@c_Parm19         = @c_Parm19'   
                       + ',@c_Parm20         = @c_Parm20' 
                       + ',@c_PrintData      = @c_PrintData OUTPUT'                       
                       + ',@b_Success        = @b_Success   OUTPUT' 
                       + ',@n_Err            = @n_Err       OUTPUT' 
                       + ',@c_ErrMsg         = @c_ErrMsg    OUTPUT'
                        
            SET @c_SQLParms= N'@n_WMReportRowID INT'
                           + ',@c_Storerkey        NVARCHAR(15)'
                           + ',@c_Facility         NVARCHAR(5)'
                           + ',@c_UserName         NVARCHAR(128)' 
                           + ',@n_Noofcopy         INT' 
                           + ',@c_PrinterID        NVARCHAR(30)' 
                           + ',@c_IsPaperPrinter   NCHAR(1)' 
                           + ',@n_Noofparms        INT' 
                           + ',@c_Parm1            NVARCHAR(60)'         
                           + ',@c_Parm2            NVARCHAR(60)'         
                           + ',@c_Parm3            NVARCHAR(60)'         
                           + ',@c_Parm4            NVARCHAR(60)'         
                           + ',@c_Parm5            NVARCHAR(60)'         
                           + ',@c_Parm6            NVARCHAR(60)'         
                           + ',@c_Parm7            NVARCHAR(60)'         
                           + ',@c_Parm8            NVARCHAR(60)'         
                           + ',@c_Parm9            NVARCHAR(60)'         
                           + ',@c_Parm10           NVARCHAR(60)'         
                           + ',@c_Parm11           NVARCHAR(60)'         
                           + ',@c_Parm12           NVARCHAR(60)'         
                           + ',@c_Parm13           NVARCHAR(60)'         
                           + ',@c_Parm14           NVARCHAR(60)'         
                           + ',@c_Parm15           NVARCHAR(60)'         
                           + ',@c_Parm16           NVARCHAR(60)'         
                           + ',@c_Parm17           NVARCHAR(60)'         
                           + ',@c_Parm18           NVARCHAR(60)'        
                           + ',@c_Parm19           NVARCHAR(60)'        
                           + ',@c_Parm20           NVARCHAR(60)'   
                           + ',@c_PrintData        NVARCHAR(MAX) OUTPUT'                                
                           + ',@b_Success          INT           OUTPUT' 
                           + ',@n_Err              INT           OUTPUT' 
                           + ',@c_ErrMsg           NVARCHAR(255) OUTPUT' 
                            
            EXEC sp_ExecuteSQL @c_SQL
                              ,@c_SQLParms 
                              ,@n_WMReportRowID  
                              ,@c_Storerkey       
                              ,@c_Facility        
                              ,@c_UserName        
                              ,@n_Noofcopy        
                              ,@c_PrinterID       
                              ,@c_IsPaperPrinter  
                              ,@n_Noofparms       
                              ,@c_Parm1              
                              ,@c_Parm2              
                              ,@c_Parm3              
                              ,@c_Parm4              
                              ,@c_Parm5              
                              ,@c_Parm6              
                              ,@c_Parm7              
                              ,@c_Parm8             
                              ,@c_Parm9             
                              ,@c_Parm10            
                              ,@c_Parm11            
                              ,@c_Parm12            
                              ,@c_Parm13            
                              ,@c_Parm14            
                              ,@c_Parm15            
                              ,@c_Parm16            
                              ,@c_Parm17            
                              ,@c_Parm18           
                              ,@c_Parm19           
                              ,@c_Parm20 
                              ,@c_PrintData     OUTPUT        
                              ,@b_Success       OUTPUT
                              ,@n_Err           OUTPUT            
                              ,@c_ErrMsg        OUTPUT            
                           
             
            IF @b_Success = 0 
            BEGIN
               SET @n_Continue = 3                 
               SET @n_err = 561102
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ' + @c_PrintTemplateSP +'. (lsp_WM_Print_ItfDoc_Wrapper)'
                              + '( ' + @c_errmsg + ' ) |' + @c_PrintTemplateSP
               GOTO EXIT_SP
            END                
                              
            SET @b_ContinuePrint = 0           
         END
      END
      
      IF @b_ContinuePrint = 1  
      BEGIN 
         IF @c_FileFolder = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 561103
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Interface File Folder Has not Setup. (lsp_WM_Print_ItfDoc_Wrapper)'
            GOTO EXIT_SP
         END

         SELECT TOP 1 @c_URLHost = ISNULL(c.Long,'')
         FROM dbo.CODELKUP AS c (NOLOCK)
         WHERE c.Listname = 'WebService' 
         AND  c.Code = 'UTLWebAPI'
         AND  c.Storerkey = ''
         AND  c.Code2= '' 

         SELECT TOP 1 
                 @c_URLPath  = ISNULL(IIF(CHARINDEX('?',c.Long,1)=0,c.Long,''),'')
               , @c_URLQuery = ISNULL(IIF(CHARINDEX('?',c.Long,1)>0,c.Long,''),'')
         FROM dbo.CODELKUP AS c WITH (NOLOCK)
         WHERE c.Listname = 'URLCfg' 
         AND  c.Code = @c_PrintType
         AND  c.Code2= 'PrintReport'         --Function
         AND  c.Storerkey = ''
       
         IF @c_URLHost = '' OR (@c_URLPath='' AND @c_URLQuery='')
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 561104
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Get Interface File URL is not setup Properly'
                          + '. Please Check Codelkup for ListName ''WebService'' and ''URLCfg'''
                          + '. (lsp_WM_Print_ItfDoc_Wrapper)'
            GOTO EXIT_SP
         END
         
         SET @c_URL = RTRIM(@c_URLHost) + RTRIM(@c_URLPath) + RTRIM(@c_URLQuery)
         
         IF OBJECT_ID('tempdb..#DirFileTree','u') IS NOT NULL
         BEGIN
            DROP TABLE #DirFileTree;
         END

         CREATE TABLE #DirFileTree 
                  (  
                     ID             INT IDENTITY(1,1) 
                  ,  SubDirectory   NVARCHAR(255) 
                  ,  Depth          SMALLINT  
                  ,  FileFlag       BIT  -- 0=folder 1=file  
                  ) 

         IF OBJECT_ID('tempdb..#ITFFile','u') IS NOT NULL
         BEGIN
            DROP TABLE #ITFFile;
         END

         CREATE TABLE #ITFFile 
                  (  
                     RowID          INT IDENTITY(1,1)       PRIMARY KEY
                  ,  ITFFile        NVARCHAR(500)  DEFAULT('')
                  ) 
         
         SET @c_FileFolder = @c_FileFolder + IIF(RIGHT(RTRIM(@c_FileFolder),1) <> '\', '\','')
         SET @c_FileArchiveFolder = @c_FileFolder + 'Archive\'
         
         --Sample: SELECT ITFFile = 'INVOICE_LZD_'+ORDERS.TrackingNo+'_PREFIX_'+ORDERS.Shipperkey+'.pdf' 
         --        FROM ORDERS (NOLOCK)
         --        JOIN PACKHEADER (NOLOCK) ON ORDERS.Orderkey = PACKHEADER.OrderKey
         --        WHERE PACKHEADER.PickSlipNo = @c_Parm1 
                         
         SET @c_SQLParms= N'@c_Parm1         NVARCHAR(60)'         
                        + ',@c_Parm2         NVARCHAR(60)'         
                        + ',@c_Parm3         NVARCHAR(60)'         
                        + ',@c_Parm4         NVARCHAR(60)'         
                        + ',@c_Parm5         NVARCHAR(60)' 
                        + ',@c_Parm6         NVARCHAR(60)'         
                        + ',@c_Parm7         NVARCHAR(60)'         
                        + ',@c_Parm8         NVARCHAR(60)'         
                        + ',@c_Parm9         NVARCHAR(60)' 
                        + ',@c_Parm10        NVARCHAR(60)'                        
                        + ',@c_Parm11        NVARCHAR(60)'         
                        + ',@c_Parm12        NVARCHAR(60)'         
                        + ',@c_Parm13        NVARCHAR(60)'         
                        + ',@c_Parm14        NVARCHAR(60)'         
                        + ',@c_Parm15        NVARCHAR(60)' 
                        + ',@c_Parm16        NVARCHAR(60)'         
                        + ',@c_Parm17        NVARCHAR(60)'         
                        + ',@c_Parm18        NVARCHAR(60)'         
                        + ',@c_Parm19        NVARCHAR(60)'         
                        + ',@c_Parm20        NVARCHAR(60)'                       
 
         INSERT INTO #ITFFile ( ITFFile )
         EXEC sp_ExecuteSQL @c_ReportTemplate
                           ,@c_SQLParms  
                           ,@c_Parm1              
                           ,@c_Parm2              
                           ,@c_Parm3              
                           ,@c_Parm4              
                           ,@c_Parm5   
                           ,@c_Parm6             
                           ,@c_Parm7              
                           ,@c_Parm8              
                           ,@c_Parm9              
                           ,@c_Parm10                                         
                           ,@c_Parm11              
                           ,@c_Parm12              
                           ,@c_Parm13              
                           ,@c_Parm14              
                           ,@c_Parm15
                           ,@c_Parm16        
                           ,@c_Parm17        
                           ,@c_Parm18        
                           ,@c_Parm19         
                           ,@c_Parm20   
              
         SET @n_RowID = 0
         WHILE 1 = 1 AND @n_Continue = 1
         BEGIN
            SELECT TOP 1
                   @n_RowID = ifi.RowID 
                 , @c_ITFFile = ifi.ITFFile
            FROM #ITFFile AS ifi 
            WHERE ifi.RowID > @n_RowID
            ORDER BY ifi.RowID

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END

            SET @c_MoveToArchive = '1'
            SET @n_Pos_Pctg = 0 
            SET @n_Pos_Pctg = CHARINDEX('%', @c_ITFFile, 1)
            IF @n_Pos_Pctg = 0                                                --Full FileName Search
            BEGIN
               SET @c_ITFFilePath = @c_FileFolder + @c_ITFFile
               EXEC dbo.xp_fileexist @c_ITFFilePath, @n_IsExists OUTPUT  
            
               IF @n_IsExists = 0 AND @c_Reprint = 'Y' 
               BEGIN 
                  SET @c_FileFolder = @c_FileArchiveFolder  
                  SET @c_ITFFilePath  = @c_FileFolder + @c_ITFFile
                  SET @c_MoveToArchive = '0'    
                  EXEC dbo.xp_fileexist @c_ITFFilePath, @n_IsExists OUTPUT
               END  
               
               IF @n_IsExists = 0                                             --2023-09-20
               BEGIN
                  SET @c_ITFFilePath = ''
               END
            END
         
            IF @n_Pos_Pctg > 0                                                --Partial FileName Search
            BEGIN
               SET @c_PrintFileFolder = @c_FileFolder
               FIND_FILE:                          
               TRUNCATE TABLE #DirFileTree;
                 
               INSERT INTO #DirFileTree (SubDirectory, Depth, FileFlag)  
               EXEC xp_dirtree_admin @c_FileFolder, 2, 1    --folder, depth 0=all(default) 1..x, 0=not list file(default) 1=list file   

               SET @c_ITFFilePath = ''
               SELECT TOP 1 @c_ITFFilePath = @c_FileFolder + SubDirectory  
               FROM #DirFileTree                                                    --2023-09-21
               WHERE SubDirectory like @c_ITFFile  
               AND Depth = 1 
            
               IF @c_ITFFilePath = '' AND @c_Reprint = 'Y' AND @c_FileFolder = @c_PrintFileFolder
               BEGIN
                  SET @c_FileFolder = @c_FileArchiveFolder
                  GOTO FIND_FILE
               END 
            
               IF @c_FileFolder = @c_FileArchiveFolder
               BEGIN
                  SET @c_MoveToArchive = '0'                                
               END
            END
         
            IF @c_ITFFilePath = ''
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 561105
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Print Interface File Not Found. (lsp_WM_Print_ItfDoc_Wrapper)'
               CONTINUE
            END 
            
            SET @c_Encrypted = ''
            SET @c_Encrypted = MASTER.dbo.fnc_CryptoEncrypt(@c_FileFolder,'') 
            
            SET @c_FileFolderURL = ''
            EXEC master.dbo.isp_URLEncode
                @c_InputString = @c_Encrypted 
               ,@c_OutputString= @c_FileFolderURL  OUTPUT 
               ,@c_vbErrMsg    = @c_ErrMsg         OUTPUT        
            
            SET @c_FileFolderURL = RTRIM(@c_FileFolderURL) 
                                      
            SET @c_FileNameURL  = CASE WHEN @c_URLQuery='' THEN ''
                                       ELSE '&filename='
                                  END
                                + RTRIM(REPLACE(@c_ITFFilePath, @c_FileFolder, ''))  
            
            SET @c_PrintData = @c_URL + @c_FileFolderURL + @c_FileNameURL 
                             + IIF(@c_MoveToArchive='1','<MoveToArchive>','')
                             
            IF @c_PrintData <> ''
            BEGIN
               EXEC [WM].[lsp_WM_SendPrintJobToProcessApp]  
                  @c_ReportID       = @c_ReportID
               ,  @c_ReportLineNo   = @c_ReportLineNo       
               ,  @c_Storerkey      = @c_Storerkey  
               ,  @c_Facility       = @c_Facility         
               ,  @n_Noofparms      = @n_Noofparms  
               ,  @c_Parm1          = @c_Parm1            
               ,  @c_Parm2          = @c_Parm2            
               ,  @c_Parm3          = @c_Parm3            
               ,  @c_Parm4          = @c_Parm4            
               ,  @c_Parm5          = @c_Parm5            
               ,  @c_Parm6          = @c_Parm6            
               ,  @c_Parm7          = @c_Parm7            
               ,  @c_Parm8          = @c_Parm8            
               ,  @c_Parm9          = @c_Parm9            
               ,  @c_Parm10         = @c_Parm10     
               ,  @c_Parm11         = @c_Parm11       
               ,  @c_Parm12         = @c_Parm12       
               ,  @c_Parm13         = @c_Parm13       
               ,  @c_Parm14         = @c_Parm14                            
               ,  @c_Parm15         = @c_Parm15         
               ,  @c_Parm16         = @c_Parm16         
               ,  @c_Parm17         = @c_Parm17         
               ,  @c_Parm18         = @c_Parm18         
               ,  @c_Parm19         = @c_Parm19         
               ,  @c_Parm20         = @c_Parm20                
               ,  @n_Noofcopy       = @n_Noofcopy          --optional
               ,  @c_PrinterID      = @c_PrinterID         --optional
               ,  @c_IsPaperPrinter = @c_IsPaperPrinter    --optional
               ,  @c_ReportTemplate = ''                   --optional
               ,  @c_PrintData      = @c_PrintData         --optional
               ,  @c_PrintType      = @c_PrintType         --ZPL / TCPSPOOLER /  ITFDOC
               ,  @c_UserName       = ''                   --optional  
               ,  @b_SCEPreView     = 0        
               ,  @n_JobID          = 0                           
               ,  @b_success        = @b_success         OUTPUT 
               ,  @n_err            = @n_err             OUTPUT 
               ,  @c_errmsg         = @c_errmsg          OUTPUT
          
               IF @n_err <> 0
               BEGIN 
                  SET @n_Continue = 3        
                  GOTO EXIT_SP               
               END 
            END     
            SET @b_ContinuePrint = 0     
         END
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
EXIT_SP:
   IF OBJECT_ID('tempdb..#ITFFILE','u') IS NOT NULL
   BEGIN
      DROP TABLE #ITFFile;
   END 

   IF OBJECT_ID('tempdb..#DirFileTree','u') IS NOT NULL
   BEGIN
      DROP TABLE #DirFileTree;
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WM_Print_ItfDoc_Wrapper'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
END -- procedure

GO