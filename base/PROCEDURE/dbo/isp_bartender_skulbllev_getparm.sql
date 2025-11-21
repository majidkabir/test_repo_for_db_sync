SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_SKULBLLEV_GetParm                                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2019-02-25 1.0  CSCHONG    Created(WMS-7989)                               */  
/* 2019-03-05 1.1  CSCHONG    WMS-8126 (CS01)                                 */
/* 2019-06-11 1.1  CSCHONG    WMS-7989 new request (CS02)                     */                            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_SKULBLLEV_GetParm]                      
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
           @c_PrintBysku       NVARCHAR(1),          --CS01
           @c_Orderkey         NVARCHAR(20)          --CS01
              
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  

      CREATE TABLE #TEMPSKULBL  (
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

   IF ISNULL(@parm03,'') = ''
   BEGIN
     SET @n_Copy = 1
   END
   ELSE
   BEGIN
     SET @n_Copy = CONVERT (INT ,@parm03)
   END

   IF EXISTS (SELECT 1 FROM SKU s WITH (NOLOCK)
              WHERE  s.storerkey =@parm01 
            AND S.SKU = @parm02 OR S.MANUFACTURERSKU = @parm02  )    --CS02
    BEGIN
     SET @c_PrintBysku = 'Y'
   END


   SET @c_SQLinsert = N'INSERT INTO #TEMPSKULBL (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10, ' +
                      ' key01,key02,key03,key04,key05)'

   IF @c_PrintBysku = 'Y'
   BEGIN
   SET @c_SQLJOIN = ''

    SET @c_SQLJOIN = 'SELECT TOP 1 PARM1=S.storerkey, ' +
                     ' PARM2=S.SKU,PARM3= '''' ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+
                     ' PARM8='''',PARM9='''',PARM10='''',Key1=''SKU'',Key2='''',Key3='''',Key4='''','+
                     ' Key5= '''' '  +  
                     ' FROM SKU S WITH (NOLOCK) ' +
                     ' where s.storerkey =@parm01 ' +
                    -- ' AND S.SKU = @parm02  '                                        --CS02
					' AND ( S.SKU = @parm02 OR S.MANUFACTURERSKU = @parm02 )    '      --CS02 
       
       SET @c_SQL = @c_SQLinsert + CHAR(13) + @c_SQLJOIN 
      
    --EXEC sp_executesql @c_SQL    
    

   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80),' +
                           '   @parm02           NVARCHAR(80),' +
                           '   @parm03           NVARCHAR(80)'      

                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @parm01    
                        , @parm02
                        , @parm03
   END
   ELSE
   BEGIN

  --   SELECT TOP 1 @c_orderkey = PH.OrderKey
    --FROM PackHeader PH WITH (nolock)
    --where  PH.PickSlipNo = @parm01

	IF EXISTS (SELECT 1 FROM STORER ST (NOLOCK)
	           JOIN ORDERS ORD WITH (NOLOCK) ON ORD.consigneekey = ST.storerkey
			   where ORD.Orderkey =  @parm05
			   AND ST.Susr1 <> 'PRICETAG')
    BEGIN
	  GOTO EXIT_SP
	END
	ELSE
	BEGIN

     SET @c_SQLJOIN = 'SELECT TOP 1 PARM1=S.storerkey, ' +
                     ' PARM2=S.SKU,PARM3= '''' ,PARM4= @parm05,PARM5='''',PARM6='''',PARM7='''', '+
                     ' PARM8='''',PARM9='''',PARM10='''',Key1=''Pickslipno'',Key2='''',Key3='''',Key4='''','+
                     ' Key5= '''' '  +  
                     ' FROM Storer ST (nolock)  ' +
					 ' JOIN SKU S WITH (NOLOCK) ON S.Storerkey = ST.Storerkey ' +
                     ' where s.storerkey =@parm04 ' +
                     ' AND S.SKU = @parm02  '  
					-- ' AND ST.Susr1 = ''PRICETAG'' '
       
       SET @c_SQL = @c_SQLinsert + CHAR(13) + @c_SQLJOIN 
      
    --EXEC sp_executesql @c_SQL    
    

   SET @c_ExecArguments = N'  @parm01           NVARCHAR(80),' +
                          '   @parm02           NVARCHAR(80),' +
                          '   @parm03           NVARCHAR(80),' +
                          '   @parm04           NVARCHAR(80),' +
                          '   @parm05           NVARCHAR(50)'       

                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @parm01    
                        , @parm02
                        , @parm03
                        , @parm04
                        , @parm05
     
    END
   END

   print @c_SQL


   WHILE @n_Copy > 1
   BEGIN
      INSERT INTO #TEMPSKULBL (PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,key01,key02,key03,key04,key05)
     SELECT TOP 1 PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,key01,key02,key03,key04,key05
     FROM #TEMPSKULBL
     Order by ROWID

     SET @n_Copy = @n_Copy - 1
   END


   SELECT PARM01,PARM02,PARM03,PARM04,PARM05,PARM06,PARM07,PARM08,PARM09,PARM10,key01,key02,key03,key04,key05
   FROM #TEMPSKULBL
   order by RowID
        
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO