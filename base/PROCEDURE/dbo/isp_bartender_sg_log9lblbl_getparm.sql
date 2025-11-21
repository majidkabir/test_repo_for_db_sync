SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_SG_LOG9LBLBL_GetParm                                */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2022-01-21 1.0  CSCHONG    Devops scripts combine - Created(WMS-18795)     */                             
/******************************************************************************/                
                  
CREATE   PROC [dbo].[isp_Bartender_SG_LOG9LBLBL_GetParm]                      
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
           @c_storerkey        NVARCHAR(20),
           @n_Copy             INT,   
           @n_rowno            INT,
           @c_PrintBysku       NVARCHAR(1),          
           @c_Orderkey         NVARCHAR(20),
           @c_stsusr1          NVARCHAR(20) = ''        
              
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  

      CREATE TABLE #TEMPLOG9LBLBL (
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
    SET @c_PrintBysku = 'N'
    SET @n_Copy = 1


            INSERT INTO #TEMPLOG9LBLBL (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,
                                         key01,key02,key03,key04,key05)
            SELECT TOP 1 PARM1=S.storerkey,PARM2=S.SKU,PARM3= @parm03 ,PARM4= @parm04,PARM5=@parm05,PARM6='',PARM7='',
                      PARM8='',PARM9='',PARM10='',Key1='',Key2='',Key3='',Key4='',
                      Key5= ''   
            FROM Storer ST (nolock) 
            JOIN SKU S WITH (NOLOCK) ON S.Storerkey = ST.Storerkey
            WHERE s.storerkey =@parm01 
            AND S.SKU = @parm02  
    

   SELECT PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,key01,key02,key03,key04,key05
   FROM #TEMPLOG9LBLBL
   order by RowID

        
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO