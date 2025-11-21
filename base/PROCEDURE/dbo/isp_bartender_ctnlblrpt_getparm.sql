SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_CTNLBLRPT_GetParm                                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2019-01-10 1.0  CSCHONG    WMS-7630                                        */                            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_CTNLBLRPT_GetParm]                      
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
	  @c_condition3      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
	  @c_storerkey       NVARCHAR(20),
	  @n_RowNo           INT,
	  @n_CtnNo           INT,
	  @n_RePrintCtn      INT
      
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_ExtOrdKey        NVARCHAR(20),
           @c_Consigneekey     NVARCHAR(50),
           @c_ExecStatements   NVARCHAR(4000),    
           @c_ExecArguments    NVARCHAR(4000)      
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = '' 
   
       CREATE TABLE #TEMPRESULT  (
    	ROWID    INT IDENTITY(1,1),
		PARM01       NVARCHAR(80),	
		PARM02       NVARCHAR(80),	
		PARM03       NVARCHAR(80),	
		PARM04       NVARCHAR(80),	
		PARM05       NVARCHAR(80),	
		PARM06       NVARCHAR(80)
     
    ) 
        
    -- SET RowNo = 0             
    SET @c_SQL = ''    
    SET @c_SQLJOIN = ''        
    SET @c_condition1 = ''
    SET @c_condition2= ''
	SET @c_condition3= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    SET @c_ExecStatements = ''
    SET @c_ExecArguments = ''

    
	IF ISNUMERIC(@parm03) <> 1 OR ISNUMERIC(@parm04) <> 1
	BEGIN
	   GOTO EXIT_SP
	END

	IF CAST(@parm03 as int) > 500
	BEGIN
	   GOTO EXIT_SP
	END

	IF CAST(@parm03 as int) < CAST(@parm04 as int) 
	BEGIN
	   GOTO EXIT_SP
	END

	SET @n_CtnNo = CAST(@parm03 AS int)
	SET @n_RePrintCtn = CAST(@parm04 AS int)

	INSERT INTO #TEMPRESULT (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06)
	SELECT ORD.Orderkey, ORD.Storerkey, @parm03,@parm04,'1',''
	FROM PICKHEADER PIH (NOLOCK)
	JOIN ORDERS ORD (NOLOCK) ON PIH.ORDERKEY = ORD.ORDERKEY
	WHERE PIH.PICKHEADERKEY = @parm02 and ORD.STORERKEY = @parm01
	--SELECT  isnull(OH.externorderkey,''), CASE WHEN isnull(OH.consigneekey,'')  THEN isnull(OH.consigneekey,'') ELSE OH.Storerkey END,
	--CASE WHEN isnull(OH.consigneekey,'') THEN 'S' ELSE 'C' END,CASE WHEN @n_RePrintCtn > 0 THEN @parm04 ELSE '1' END,@Parm03,PH.pickheaderkey
 --   FROM orders OH as (nolock)
 --   JOIN pickheader PH as (nolock) on OH.orderkey = PH.orderkey
 --   where PH.pickheaderkey = @Parm02
	--AND OH.Storerkey = @Parm01

	SET @n_RowNo = 2

	WHILE( CAST(@parm04 as int) = 0 AND @n_CtnNo > 1 )
	BEGIN
	INSERT INTO #TEMPRESULT (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06)
	SELECT PARM01,PARM02,@parm03,@parm04,CAST(@n_RowNo AS nvarchar(10)),PARM06
	FROM #TEMPRESULT
	WHERE ROWID = 1

	   SET @n_RowNo = @n_RowNo + 1
	   SET @n_CtnNo = @n_CtnNo - 1

	END
	
	--orderkey,storerkey,reprintctn,ttlctn
    SELECT DISTINCT PARM1=PARM01,PARM2=PARM02,PARM3=PARM03,PARM4=PARM04,PARM5=CASE WHEN CAST(@parm04 AS INT) = 0 
	                THEN ROWID ELSE @parm04 END,PARM6='',PARM7='', 
		            PARM8='',PARM9='',PARM10='',Key1='Orderkey',Key2='Storerkey',Key3='TTLCtn',Key4='ReprintCtn',
					 Key5= 'CartonNo'
			         FROM #TEMPRESULT
					 where PARM02 =  @Parm01
					 ORDER BY CASE WHEN CAST(@parm04 AS INT) = 0 THEN ROWID ELSE @parm04 END
  
						         
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO