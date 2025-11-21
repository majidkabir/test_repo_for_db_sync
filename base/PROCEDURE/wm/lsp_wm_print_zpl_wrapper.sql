SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: WM.lsp_WM_Print_ZPL_Wrapper                             */
/* Creation Date: 2023-02-15                                            */
/* Copyright: Maersk                                                    */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: NextGen Ecom Packing                                        */
/*        : PAC-15:Ecom Packing | Print Packing Report                  */
/*                            - Backend                                 */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2023-02-15  Wan      1.0   Created & DevOps Combine Script           */ 
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_Print_ZPL_Wrapper]
   @n_WMReportRowID      BIGINT 
,  @c_Storerkey          NVARCHAR(15)
,  @c_Facility           NVARCHAR(5)
,  @c_UserName           NVARCHAR(128)  
,  @n_Noofcopy           INT            = 1                                                   
,  @c_PrinterID          NVARCHAR(100)  = ''
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
  
         , @n_RowID                 INT               = 0

         , @c_SourceType            NVARCHAR(50)      = 'lsp_WM_Print_ZPL_Wrapper'
         , @c_ReportID              NVARCHAR(10)      = ''
         , @c_ReportLineNo          NVARCHAR(5)       = ''
         , @c_ReportType            NVARCHAR(30)      = ''
         , @c_PrintType             NVARCHAR(30)      = ''
         
         , @c_PrintData             NVARCHAR(MAX)     = ''
         , @c_PrintSettings         NVARCHAR(4000)    = ''
         , @c_ReportTemplate        NVARCHAR(1000)    = ''
         , @c_PrintTemplateSP       NVARCHAR(1000)    = ''

         , @c_SQL                   NVARCHAR(MAX)     = ''
         , @c_SQLParms              NVARCHAR(2000)    = ''  
         , @c_SQL_Select            NVARCHAR(MAX)     = ''

   BEGIN TRY
      SELECT @c_ReportID = w.ReportID
            ,@c_ReportType = w2.ReportType
            ,@c_PrintType  = w.Printtype
            ,@c_PrintSettings = w.PrintSettings
            ,@c_ReportLineNo = w.ReportLineNo
            ,@c_ReportTemplate = w.ReportTemplate           
            ,@c_PrintTemplateSP = w.PrintTemplateSP
            ,@c_SQL_Select = w.SQL_Select
      FROM dbo.WMREPORTDETAIL AS w WITH (NOLOCK)
      JOIN dbo.WMREPORT AS w2 WITH (NOLOCK) ON w2.ReportID = w.ReportID
      WHERE w.RowID = @n_WMReportRowID

      IF @c_ReportTemplate <> 'SQL_Select_Ref'
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE id = Object_ID(@c_PrintTemplateSP)AND TYPE = 'P')
         BEGIN
            SET @c_SQL = N'EXEC ' + @c_PrintTemplateSP
                       + ' @n_WMReportRowID= @n_WMReportRowID' 
                       + ',@c_Parm1        = @c_Parm1'   
                       + ',@c_Parm2        = @c_Parm2'  
                       + ',@c_Parm3        = @c_Parm3'  
                       + ',@c_Parm4        = @c_Parm4'  
                       + ',@c_Parm5        = @c_Parm5'  
                       + ',@c_Parm6        = @c_Parm6'  
                       + ',@c_Parm7        = @c_Parm7'  
                       + ',@c_Parm8        = @c_Parm8'  
                       + ',@c_Parm9        = @c_Parm9'  
                       + ',@c_Parm10       = @c_Parm10'   
                       + ',@c_Parm11       = @c_Parm11'   
                       + ',@c_Parm12       = @c_Parm12'   
                       + ',@c_Parm13       = @c_Parm13'   
                       + ',@c_Parm14       = @c_Parm14'   
                       + ',@c_Parm15       = @c_Parm15'   
                       + ',@c_Parm16       = @c_Parm16'   
                       + ',@c_Parm17       = @c_Parm17'   
                       + ',@c_Parm18       = @c_Parm18'   
                       + ',@c_Parm19       = @c_Parm19'   
                       + ',@c_Parm20       = @c_Parm20' 
                       + ',@c_PrintData    = @c_PrintData OUTPUT'
                       + ',@b_Success      = @b_Success   OUTPUT' 
                       + ',@n_Err          = @n_Err       OUTPUT' 
                       + ',@c_ErrMsg       = @c_ErrMsg    OUTPUT'
                        
            SET @c_SQLParms= N'@n_WMReportRowID INT'
                           + ',@c_Parm1         NVARCHAR(60)'         
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
                           + ',@c_PrintData     NVARCHAR(MAX) OUTPUT'    
                           + ',@b_Success       INT           OUTPUT' 
                           + ',@n_Err           INT           OUTPUT' 
                           + ',@c_ErrMsg        NVARCHAR(255) OUTPUT' 
                            
            EXEC sp_ExecuteSQL @c_SQL
                              ,@c_SQLParms 
                              ,@n_WMReportRowID   
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
                              ,@c_PrintData OUTPUT 
                              ,@b_Success   OUTPUT
                              ,@n_Err       OUTPUT            
                              ,@c_ErrMsg    OUTPUT            
                           
            IF @b_Success = 0 
            BEGIN
               SET @n_Continue = 3                 
               SET @n_err = 561201
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ' + @c_PrintTemplateSP 
                             +'. (lsp_WM_Print_ZPL_Wrapper)( ' + @c_errmsg + ' )'
               GOTO EXIT_SP
            END  
         END   
      END 
         
      IF @c_ReportTemplate= 'SQL_Select_Ref' AND @c_SQL_Select <> ''
      BEGIN
         IF OBJECT_ID('tempdb..#ZPLData','u') IS NOT NULL
         BEGIN
            DROP TABLE #ZPLData;
         END
         
         CREATE TABLE #ZPLData
            ( RowID        INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
            , PrintData    NVARCHAR(MAX)  NOT NULL DEFAULT('')
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
 
         INSERT INTO #ZPLData ( PrintData )
         EXEC sp_ExecuteSQL @c_SQL_Select
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
                   @n_RowID = zd.RowID 
                 , @c_PrintData = zd.PrintData
            FROM #ZPLData AS zd 
            WHERE zd.RowID > @n_RowID
            ORDER BY zd.RowID

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END       
                
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
            END  
         END    
      END
   END TRY
 
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
EXIT_SP:
   IF OBJECT_ID('tempdb..#ZPLData','u') IS NOT NULL
   BEGIN
      DROP TABLE #ZPLData;
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WM_Print_ZPL_Wrapper'
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