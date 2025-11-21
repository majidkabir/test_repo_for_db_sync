SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_SIGPICKLBL_GetParm                                  */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-06-18 1.0  CSCHONG    Created(WMS-7510)                               */                            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_CN_SKESHIPLBL_GetParm]                      
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
      @c_SQLOrdBy        NVARCHAR(150)
      
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),    
           @c_ExecArguments    NVARCHAR(4000)      
  
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

	CREATE TABLE #TEMPORDERS (
		RowID          INT IDENTITY (1,1) NOT NULL ,
		storerkey      NVARCHAR(20),
		Loadkey        NVARCHAR(30) ,
		Orderkey       NVARCHAR(30),
		Qty            INT  )

	IF ISNULL(@parm02,'')  <> ''
    BEGIN       
	   INSERT INTO #TEMPORDERS (storerkey,Loadkey,Orderkey,Qty)
	   SELECT OH.Storerkey,OH.loadkey,OH.Orderkey,SUM(PD.Qty)
	   FROM ORDERS OH WITH (NOLOCK)
	   JOIN PICKDETAIL PD (NOLOCK) ON OH.OrderKey=PD.OrderKey
	   WHERE OH.Loadkey = @parm01
	   AND OH.Orderkey = @parm02
	   GROUP BY OH.Storerkey,OH.loadkey,OH.Orderkey
    END 
	ELSE
	BEGIN
	  INSERT INTO #TEMPORDERS (storerkey,Loadkey,Orderkey,qty)
	   SELECT OH.Storerkey,OH.loadkey,OH.Orderkey,SUM(PD.Qty)
	   FROM ORDERS OH WITH (NOLOCK)
	   JOIN PICKDETAIL PD (NOLOCK) ON OH.OrderKey=PD.OrderKey
	   WHERE OH.Loadkey = @parm01
	   --AND OH.Orderkey = @parm02
	   GROUP BY OH.Storerkey,OH.loadkey,OH.Orderkey
	END   
    

	 SET @c_SQLOrdBy = 'ORDER BY TOH.loadkey,TOH.OrderKey, RTRIM(P.sku)'

	 SET  @c_SQLGroup = 'GROUP by TOH.loadkey,TOH.OrderKey, RTRIM(P.sku),TOH.Qty'

    SET @c_SQLJOIN = 'SELECT DISTINCT PARM1= TOH.loadkey,PARM2=TOH.OrderKey,PARM3= RTRIM(P.sku),PARM4= TOH.Qty,PARM5='''',PARM6='''',PARM7='''', '+
					 'PARM8='''',PARM9='''',PARM10='''',Key1=''LoadKey'',Key2=''orderkey'',Key3='''',Key4='''','+
					 ' Key5= '''' '  +  
					 ' FROM   PICKDETAIL P WITH (NOLOCK) '+  
					-- ' JOIN Orders OH (NOLOCK) ON OH.orderkey=P.orderkey and OH.storerkey=P.Storerkey   '+
					 ' JOIN #TEMPORDERS TOH (NOLOCK) ON TOH.orderkey=P.orderkey and TOH.storerkey=P.Storerkey   '+
					 ' WHERE TOH.LoadKey =  @parm01  '
   
    
    	 IF ISNULL(@parm02,'')  <> ''
    	 BEGIN       
		    SET @c_condition1 = ' AND TOH.OrderKey =  @parm02  '
    	 END     
    	 
    	 SET @c_SQL = @c_SQLJOIN + @c_condition1 +CHAR(13)  + @c_SQLGroup + CHAR(13) + @c_SQLOrdBy
    	
    	-- PRINT @c_SQL
    	
    --EXEC sp_executesql @c_SQL    

   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL          
   END
    

   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80)'    
                          + ', @parm02           NVARCHAR(80) '    
                          + ', @parm03           NVARCHAR(80)'   
                          + ', @parm04           NVARCHAR(80) '    
                          + ', @parm05           NVARCHAR(80)'  
                          + ', @parm06           NVARCHAR(80)'  
                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @parm01    
                        , @parm02   
                        , @parm03
                        , @parm04
                        , @parm05  
                        , @parm06

   DROP TABLE #TEMPORDERS
            
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO