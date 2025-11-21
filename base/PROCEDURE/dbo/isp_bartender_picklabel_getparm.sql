SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_PICKLABEL_GetParm                                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-06-28 1.0  CSCHONG    Created(WMS-4974&WMS-4979&WMS-5049)             */     
/* 2019-04-15 1.1  WLCHOOI    Modify to cater for WMS-8627 (WL01)             */   
/* 2019-12-27 1.2  WLChooi    WMS-11507 - Enhance after WMS-8627 (WL02)       */ 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_PICKLABEL_GetParm]                      
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
           @n_count            INT,         --WL01
           @c_ECOM_Flag        NVARCHAR(1)  --WL02
  
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

    --WL02 Start
    SELECT TOP 1 @c_ECOM_Flag = ISNULL(ORDERS.ECOM_SINGLE_Flag,'')
    FROM LOADPLANDETAIL (NOLOCK)
    JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY
    WHERE LOADPLANDETAIL.LOADKEY = @parm02
    --WL02 End

	 CREATE TABLE #TEMP_PICKBYQTY (
	 Pickdetailkey            NVARCHAR(50),
	 PQTY                     INT,
	 Storerkey                NVARCHAR(20)
	 )
    
	 IF ISNULL(@parm03,'') <> ''
	 BEGIN
	   SET @c_condition1 = ' AND OS.orderkey = @parm03 '
	 END

	 SET @c_SQLinsert = N'INSERT INTO #TEMP_PICKBYQTY (Pickdetailkey,Pqty,Storerkey) '

	 SET @c_SQLSelect = N' SELECT PD.PickDetailKey,PD.Qty,PD.storerkey' +
	                     ' FROM PickDetail PD(NOLOCK) ' +  
                        ' JOIN Orders OS(NOLOCK) ON PD.Orderkey=OS.Orderkey ' +
                        ' WHERE PD.Storerkey = @parm01 and OS.loadkey = @parm02'

    SET @c_SQL = @c_SQLinsert + CHAR(13) + @c_SQLSelect + CHAR(13) + @c_condition1 

	 SET @c_ExecArguments = N' @parm01           NVARCHAR(80)'    
                         + ', @parm02           NVARCHAR(80) '    
                         + ', @parm03           NVARCHAR(80)'   

                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @parm01    
                        , @parm02   
                        , @parm03
  --select * from #TEMP_PICKBYQTY

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Pickdetailkey,Pqty,Storerkey
   FROM  #TEMP_PICKBYQTY  
   where pqty>1
   order by Pickdetailkey
    
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_Pickdetkey,@n_pqty,@c_storerkey     
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN 
   
   SET @n_rowno = 1

	WHILE @n_pqty >1
	BEGIN
	   

	   INSERT INTO #TEMP_PICKBYQTY (Pickdetailkey,Pqty,Storerkey)
	   VALUES (@c_Pickdetkey,0,@c_storerkey)
	   
	   SET @n_pqty = @n_pqty -1

	END

	

	FETCH NEXT FROM CUR_RESULT INTO @c_Pickdetkey,@n_pqty,@c_storerkey    
	END
	
	SET @c_SQL = ''
	SET @c_condition1 = ''
   SET @c_SQLOrdBy = ''
	
	SELECT @n_Count = COUNT (1) FROM #TEMP_PICKBYQTY      --WL01
	
   --WL01 START
   IF(@parm01 = '18505')
   BEGIN
      SET @c_SQLJOIN = 'SELECT PARM1=ROW_NUMBER() OVER (Order by PD.LOC, PD.SKU), ' +
                     ' PARM2=PD.OrderKey,PARM3= PD.SKU ,PARM4= PD.loc,PARM5=@parm02,PARM6=A2.loadseq,PARM7=@parm01, '+
                     ' PARM8='''',PARM9='''',PARM10=CAST(@n_Count AS NVARCHAR(80)),Key1=''loadkey'',Key2=@c_ECOM_Flag,Key3='''',Key4='''','+   --WL01  --WL02
                     ' Key5= '''' '  +  
                     ' FROM #TEMP_PICKBYQTY TMP '  +
                     ' JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Pickdetailkey = TMP.Pickdetailkey '+  
                     ' JOIN ORDERS OH WITH (NOLOCK) ON OH.orderkey = pd.orderkey' +
                     ' JOIN LOC L WITH (NOLOCK) ON L.loc = PD.loc ' +
                     ' INNER JOIN (SELECT ROW_NUMBER() OVER (ORDER BY OrderKey) as loadseq ,orderkey from orders WITH (nolock) ' +
                     ' where Loadkey =@parm02) as A2 on PD.Orderkey = A2.Orderkey ' +
                     ' WHERE PD.storerkey =  @parm01  '   +
                     ' Order by PD.LOC, PD.SKU '
   END  
   ELSE
   BEGIN    --WL01 END
	   SET @c_SQLJOIN = 'SELECT PARM1=ROW_NUMBER() OVER (Order by L.LogicalLocation,PD.LOC), ' +
                        ' PARM2=PD.OrderKey,PARM3= PD.SKU ,PARM4= PD.loc,PARM5=@parm02,PARM6=A2.loadseq,PARM7=@parm01, '+
                        ' PARM8='''',PARM9='''',PARM10='''',Key1=''loadkey'',Key2='''',Key3='''',Key4='''','+   
                        ' Key5= '''' '  +  
                        ' FROM #TEMP_PICKBYQTY TMP '  +
                        ' JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Pickdetailkey = TMP.Pickdetailkey '+  
                        ' JOIN ORDERS OH WITH (NOLOCK) ON OH.orderkey = pd.orderkey' +
                        ' JOIN LOC L WITH (NOLOCK) ON L.loc = PD.loc ' +
                        ' INNER JOIN (SELECT ROW_NUMBER() OVER (ORDER BY OrderKey) as loadseq ,orderkey from orders WITH (nolock) ' +
                        ' where Loadkey =@parm02) as A2 on PD.Orderkey = A2.Orderkey ' +
                        ' WHERE PD.storerkey =  @parm01  '
   END
     
    	 
  SET @c_SQL = @c_SQLJOIN + @c_condition1
    	
  PRINT @c_SQL
    	
    --EXEC sp_executesql @c_SQL    
    

  SET @c_ExecArguments = N'   @parm01           NVARCHAR(80),' +
                          '   @parm02           NVARCHAR(80),' +
                          '   @n_count          NVARCHAR(80),' + --WL01
                          '   @c_ECOM_Flag      NVARCHAR(80) '   --WL02

                         
                         
  EXEC sp_ExecuteSql     @c_SQL     
                       , @c_ExecArguments    
                       , @parm01    
                       , @parm02
                       , @n_count      --WL01
                       , @c_ECOM_Flag  --WL02
      
								
 --select * from #TEMP_PICKBYQTY

            
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO