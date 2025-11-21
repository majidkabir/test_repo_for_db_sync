SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_TH_SKUPDCTLBL_GetParm                               */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2021-11-18 1.0  CSCHONG    Devops Scripts combine and Created(WMS-18370)   */                            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_TH_SKUPDCTLBL_GetParm]                      
(  @parm01            NVARCHAR(250),              
   @parm02            NVARCHAR(250),              
   @parm03            NVARCHAR(250),              
   @parm04            NVARCHAR(250),              
   @parm05            NVARCHAR(250),              
   @parm06            NVARCHAR(250),              
   @parm07            NVARCHAR(250),              
   @parm08            NVARCHAR(250),              
   @parm09            NVARCHAR(250),              
   @parm10            NVARCHAR(250),        
   @b_debug           INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
                              
   DECLARE                     
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_SQLinsert       NVARCHAR(4000) ,  
      @c_SQLSelect       NVARCHAR(4000)   
      
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),    
           @c_ExecArguments    NVARCHAR(4000),
           @c_Pickdetkey       NVARCHAR(50),
           @c_storerkey        NVARCHAR(20),
           @n_Pqty             INT,   
           @n_rowno            INT,
           @n_copy             INT = 0   
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''    
    SET @c_SQLJOIN = ''        
    SET @c_condition1 = ''
    SET @c_condition2= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    SET @c_ExecStatements = ''
    SET @c_ExecArguments = ''
    SET @c_SQLinsert = ''
    SET @c_SQLSelect = ''


   IF ISNULL(@parm03,'') = ''
   BEGIN
     SET @n_Copy = 1
   END
   ELSE
   BEGIN
     SET @n_Copy = CONVERT (INT ,@parm03)
   END
   

   IF @n_copy > 99
   BEGIN
       GOTO EXIT_SP
   END 


    CREATE TABLE #TEMPTHSKUPDCTLBL  (
      ROWID       INT IDENTITY(1,1),
      PARM01       NVARCHAR(80) NULL DEFAULT(''),  
      PARM02       NVARCHAR(80) NULL DEFAULT(''),  
      PARM03       NVARCHAR(80) NULL DEFAULT(''),  
      PARM04       NVARCHAR(80) NULL DEFAULT(''),  
      PARM05       NVARCHAR(80) NULL DEFAULT(''),  
      PARM06       NVARCHAR(80) NULL DEFAULT(''),  
      PARM07       NVARCHAR(80) NULL DEFAULT(''),
      PARM08       NVARCHAR(80) NULL DEFAULT(''),
      PARM09       NVARCHAR(80) NULL DEFAULT(''),
      PARM10       NVARCHAR(80) NULL DEFAULT(''),
      Key01        NVARCHAR(80) NULL DEFAULT(''),
      Key02        NVARCHAR(80) NULL DEFAULT(''),
      Key03        NVARCHAR(80) NULL DEFAULT(''),
      Key04        NVARCHAR(80) NULL DEFAULT(''),
      Key05        NVARCHAR(80) NULL DEFAULT(''))

    SET @c_SQL = ''
    SET @c_condition1 = ''

   
    INSERT INTO #TEMPTHSKUPDCTLBL (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,
                                         key01,key02,key03,key04,key05)
     SELECT DISTINCT PARM1=S.storerkey, PARM2=S.sku,PARM3= '' ,PARM4='',PARM5='',PARM6='',PARM7='', 
                     PARM8='',PARM9='',PARM10='',Key1='storerkey',Key2='sku',Key3='',Key4='', Key5='' 
                     FROM SKU S WITH (NOLOCK) 
                     WHERE S.storerkey =@parm01 
                     AND S.SKU = @parm02  
       
     


   WHILE @n_Copy > 1
   BEGIN
      INSERT INTO #TEMPTHSKUPDCTLBL (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,key01,key02,key03,key04,key05)
     SELECT TOP 1 PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,key01,key02,key03,key04,key05
     FROM #TEMPTHSKUPDCTLBL
     Order by ROWID

     SET @n_Copy = @n_Copy - 1
   END


   SELECT PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,key01,key02,key03,key04,key05
   FROM #TEMPTHSKUPDCTLBL
   order by RowID
            
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
      DROP TABLE #TEMPTHSKUPDCTLBL
                                  
   END -- procedure   


GO