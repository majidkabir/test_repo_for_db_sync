SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: WM.lsp_WM_Print_TPPrint_Wrapper                         */
/* Creation Date: 2023-02-15                                            */
/* Copyright: Maersk                                                    */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:PAC-15:Ecom Packing | Print Packing Report                   */
/*        :                                                             */
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
/* 2023-10-09  Wan01    1.1   Fixed.                                    */
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_Print_TPPrint_Wrapper]
   @n_WMReportRowID      BIGINT 
,  @c_Storerkey          NVARCHAR(15)
,  @c_Facility           NVARCHAR(5)
,  @c_UserName           NVARCHAR(128)  = '' 
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
,  @b_Success            INT            OUTPUT
,  @n_Err                INT            OUTPUT
,  @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT               = @@TRANCOUNT
         , @n_Continue              INT               = 1
         , @n_JobNo                 BIGINT            = 0
         , @c_JobNo                 NVARCHAR(10)      = ''         
                 
         , @b_ContinuePrint         BIT               = 0
         , @c_Printer               NVARCHAR(128)     = ''

         , @c_SourceType            NVARCHAR(50)      = 'lsp_WM_Print_TPPrint_Wrapper'
         , @c_ModuleID              NVARCHAR(30)      = ''
         , @c_ReportID              NVARCHAR(10)      = ''
         , @c_ReportType            NVARCHAR(30)      = ''
         , @c_KeyFieldName          NVARCHAR(100)     = ''
         , @c_ReportLineNo          NVARCHAR(5)       = ''
         , @c_PrintType             NVARCHAR(30)      = ''
         , @c_ReportTemplate        NVARCHAR(4000)    = ''
         , @c_SQL_Select            NVARCHAR(Max)     = ''
         
         , @c_Shipperkey            NVARCHAR(15)      = ''
         , @c_Platform              NVARCHAR(50)      = ''         
         , @c_UDF01                 NVARCHAR(100)     = ''
         , @c_UDF02                 NVARCHAR(100)     = ''
         , @c_UDF03                 NVARCHAR(100)     = ''
         , @c_UDF04                 NVARCHAR(100)     = ''
         , @c_UDF05                 NVARCHAR(100)     = '' 
         , @c_TPP_Parm1             NVARCHAR(60)      = ''
         , @c_TPP_Parm2             NVARCHAR(60)      = ''
         , @c_TPP_Parm3             NVARCHAR(60)      = ''
         , @c_TPP_Parm4             NVARCHAR(60)      = ''
         , @c_TPP_Parm5             NVARCHAR(60)      = ''
         , @c_TPP_Parm6             NVARCHAR(60)      = ''
         , @c_TPP_Parm7             NVARCHAR(60)      = ''
         , @c_TPP_Parm8             NVARCHAR(60)      = ''
         , @c_TPP_Parm9             NVARCHAR(60)      = ''
         , @c_TPP_Parm10            NVARCHAR(60)      = '' 
         , @c_TPPrint_SP            NVARCHAR(30)      = '' 

         , @c_PrintData             NVARCHAR(MAX)     = ''     

         , @c_SQL                   NVARCHAR(MAX)     = ''
         , @c_SQLParms              NVARCHAR(MAX)     = ''
         
         , @CUR_TPP                 CURSOR
         
   DECLARE @t_TPPJob TABLE (JobNo BIGINT)           
   BEGIN TRY        
      SELECT @c_ModuleID    = w2.ModuleID
            ,@c_ReportID    = w2.ReportID      
            ,@c_ReportType  = w2.ReportType
            ,@c_KeyFieldName= w2.KeyFieldName1
            ,@c_ReportLineNo= w.ReportLineNo
            ,@c_PrintType   = w.PrintType
            ,@c_ReportTemplate = w.ReportTemplate
            ,@c_SQL_Select  = w.SQL_Select             --SQL to get data to send to webservice
      FROM dbo.WMREPORTDETAIL AS w WITH (NOLOCK)
      JOIN dbo.WMREPORT AS w2 WITH (NOLOCK) ON w2.ReportID = w.ReportID
      WHERE w.RowID = @n_WMReportRowID
      
      IF @c_ReportTemplate = ''
      BEGIN
         GOTO EXIT_SP
      END
      
      IF @c_PrinterID = ''
      BEGIN
         SELECT @c_PrinterID = CASE WHEN @c_IsPaperPrinter = 'N' THEN ru.DefaultPrinter
                                    ELSE ru.DefaultPrinter_Paper
                                    END
         FROM rdt.RDTUser AS ru WITH (NOLOCK)
         WHERE ru.UserName = @c_UserName                                            --(Wan01)
      END         
      
      IF @c_PrinterID = ''
      BEGIN
         SET @n_Continue = 3        
         SET @n_err = 561151
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Printer ID is required.'
                       + '. (lsp_WM_Print_TPPrint_Wrapper)'
         GOTO EXIT_SP               
      END
      
      SELECT @c_Printer = rp.WinPrinter
      FROM rdt.RDTPrinter AS rp (NOLOCK)
      WHERE rp.PrinterID = @c_PrinterID
         
      IF CHARINDEX(',',@c_Printer,1) > 0
      BEGIN
         SET @c_Printer = LEFT(@c_Printer,CHARINDEX(',',@c_Printer,1) - 1)
      END     
          
      IF OBJECT_ID('tempdb..#ShipperCfg','u') IS NOT NULL
      BEGIN
         DROP TABLE #ShipperCfg;
      END
         
      CREATE TABLE #ShipperCfg
         ( [RowID]      INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         , [Storerkey]  NVARCHAR(15)   NOT NULL DEFAULT('')
         , [ShipperKey] NVARCHAR(15)   NOT NULL DEFAULT('')    
         , [Module]     NVARCHAR(10)   NOT NULL DEFAULT('') 
         , [ReportType] NVARCHAR(10)   NOT NULL DEFAULT('')   
         , [PlatForm]   NVARCHAR(10)   NOT NULL DEFAULT('')  
         , [TPP_Parm1]  NVARCHAR(60)   NOT NULL DEFAULT('')
         , [TPP_Parm2]  NVARCHAR(60)   NOT NULL DEFAULT('')
         , [TPP_Parm3]  NVARCHAR(60)   NOT NULL DEFAULT('')
         , [TPP_Parm4]  NVARCHAR(60)   NOT NULL DEFAULT('')
         , [TPP_Parm5]  NVARCHAR(60)   NOT NULL DEFAULT('')
         , [TPP_Parm6]  NVARCHAR(60)   NOT NULL DEFAULT('')
         , [TPP_Parm7]  NVARCHAR(60)   NOT NULL DEFAULT('')
         , [TPP_Parm8]  NVARCHAR(60)   NOT NULL DEFAULT('')
         , [TPP_Parm9]  NVARCHAR(60)   NOT NULL DEFAULT('')
         , [TPP_Parm10] NVARCHAR(60)   NOT NULL DEFAULT('')                                               
         ) 
              
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
 
      INSERT INTO #ShipperCfg ([Storerkey],[ShipperKey],[Module],[ReportType],[PlatForm]
                              ,[TPP_Parm1],[TPP_Parm2],[TPP_Parm3],[TPP_Parm4],[TPP_Parm5]
                              ,[TPP_Parm6],[TPP_Parm7],[TPP_Parm8],[TPP_Parm9],[TPP_Parm10]                              
                              )
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
     
      IF CHARINDEX('.',@c_KeyFieldName) > 0 
      BEGIN
         SET @c_KeyFieldName = RIGHT(@c_KeyFieldName,LEN(@c_KeyFieldName)-CHARINDEX('.',@c_KeyFieldName))
      END

      SET @CUR_TPP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT  sc.ShipperKey
            , sc.[PlatForm]
            , sc.TPP_Parm1
            , sc.TPP_Parm2
            , sc.TPP_Parm3
            , sc.TPP_Parm4
            , sc.TPP_Parm5  
            , sc.TPP_Parm6
            , sc.TPP_Parm7
            , sc.TPP_Parm8
            , sc.TPP_Parm9 
            , sc.TPP_Parm10                     
            , UDF01 = ISNULL(t.UDF01,'')
            , UDF02 = ISNULL(t.UDF02,'') 
            , UDF03 = ISNULL(t.UDF03,'') 
            , UDF04 = ISNULL(t.UDF04,'') 
            , UDF05 = ISNULL(t.UDF05,'')  
            , t.TPPrint_StoredProc                                                          
      FROM #ShipperCfg AS sc 
      JOIN dbo.TPPRINTCONFIG AS t (NOLOCK) ON  t.Storerkey = sc.Storerkey
                                           AND t.Shipperkey = sc.ShipperKey 
                                           AND t.Module = sc.MODULE 
                                           AND t.ReportType = sc.ReportType
                                           AND t.[Platform] = sc.[PlatForm]
      ORDER BY sc.RowID
      
      OPEN @CUR_TPP
      
      FETCH NEXT FROM @CUR_TPP INTO @c_Shipperkey
                                 ,  @c_Platform
                                 ,  @c_TPP_Parm1
                                 ,  @c_TPP_Parm2 
                                 ,  @c_TPP_Parm3 
                                 ,  @c_TPP_Parm4 
                                 ,  @c_TPP_Parm5
                                 ,  @c_TPP_Parm6
                                 ,  @c_TPP_Parm7 
                                 ,  @c_TPP_Parm8
                                 ,  @c_TPP_Parm9
                                 ,  @c_TPP_Parm10                                                                     
                                 ,  @c_UDF01 
                                 ,  @c_UDF02 
                                 ,  @c_UDF03 
                                 ,  @c_UDF04 
                                 ,  @c_UDF05  
                                 ,  @c_TPPrint_SP  
                                            
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
         DELETE FROM @t_TPPJob;
         
         INSERT INTO TPPRINTJOB 
            (  Module, ReportType, Storerkey, Shipperkey, [Platform]
            ,  PrinterID, Printer, [Status], [Message], KeyFieldName   
            ,  Parm01, Parm02, Parm03, Parm04, Parm05
            ,  Parm06, Parm07, Parm08, Parm09, Parm10 
            ,  UDF01, UDF02, UDF03, UDF04, UDF05, SourceType)  
         OUTPUT INSERTED.JobNo INTO @t_TPPJob  
         VALUES 
            (  @c_ModuleID, @c_ReportType, @c_Storerkey, @c_Shipperkey, @c_Platform
            ,  @c_PrinterID, @c_Printer, '0', '', @c_KeyFieldName  
            ,  @c_TPP_Parm1, @c_TPP_Parm2, @c_TPP_Parm3, @c_TPP_Parm4, @c_TPP_Parm5
            ,  @c_TPP_Parm6, @c_TPP_Parm7, @c_TPP_Parm8, @c_TPP_Parm9, @c_TPP_Parm10   
            ,  @c_UDF01, @c_UDF02, @c_UDF03, @c_UDF04, @c_UDF05, @c_SourceType
            )     
                                           
         SET @n_JobNo = 0
         SET @c_JobNo = ''                            
         SELECT @n_JobNo = JobNo FROM @t_TPPJob  
         SET @c_JobNo = CONVERT(NVARCHAR(10), @n_JobNo)  

         SET @c_PrintData = N'EXEC ' + @c_TPPrint_SP + ' @n_JobNo=' + @c_JobNo
    
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
         ,  @c_PrintType      = @c_PrintType         --ZPL / TCPSPOOLER /  ITFFILE
         ,  @c_UserName       = ''                   --optional  
         ,  @b_SCEPreView     = 0        
         ,  @n_JobID          = 0                               
         ,  @b_success        = @b_success          OUTPUT 
         ,  @n_err            = @n_err              OUTPUT 
         ,  @c_errmsg         = @c_errmsg           OUTPUT
               
         IF @n_Err <> 0
         BEGIN 
            SET @n_Continue = 3        
            GOTO EXIT_SP               
         END
         
         FETCH NEXT FROM @CUR_TPP INTO @c_Shipperkey
                                    ,  @c_Platform
                                    ,  @c_TPP_Parm1
                                    ,  @c_TPP_Parm2 
                                    ,  @c_TPP_Parm3 
                                    ,  @c_TPP_Parm4 
                                    ,  @c_TPP_Parm5
                                    ,  @c_TPP_Parm6
                                    ,  @c_TPP_Parm7 
                                    ,  @c_TPP_Parm8
                                    ,  @c_TPP_Parm9
                                    ,  @c_TPP_Parm10                                                                     
                                    ,  @c_UDF01 
                                    ,  @c_UDF02 
                                    ,  @c_UDF03 
                                    ,  @c_UDF04 
                                    ,  @c_UDF05  
                                    ,  @c_TPPrint_SP                                     
      END
      CLOSE @CUR_TPP
      DEALLOCATE @CUR_TPP
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
EXIT_SP:
   IF OBJECT_ID('tempdb..#ShipperCfg','u') IS NOT NULL
   BEGIN
      DROP TABLE #ShipperCfg;
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'WM.lsp_WM_Print_TPPrint_Wrapper'
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

END -- procedure

GO