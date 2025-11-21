SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/               
/* Copyright: IDS                                                             */               
/* Purpose:                                                                   */               
/*                                                                            */               
/* Modifications log:                                                         */               
/*                                                                            */               
/* Date           Rev  Author     Purposes                                    */  
/* 2022-04-15     1.0  MINGLE     Created (WMS-19440)                         */   
/* 2022-04-15     1.0  MINGLE     DevOps Combine Script                       */ 
/* 2023-05-08     1.1  CSCHONG    WMS-22423 add new field (CS01)              */
/* 2023-08-01     1.2  CSCHONG    WMS-23148 add new field (CS02)              */
/******************************************************************************/              
                
CREATE   PROC [dbo].[isp_BT_Bartender_Shipper_Label_WAYBILL_AG]                     
(  @c_Sparm1            NVARCHAR(250),            
   @c_Sparm2            NVARCHAR(250),            
   @c_Sparm3            NVARCHAR(250),            
   @c_Sparm4            NVARCHAR(250),            
   @c_Sparm5            NVARCHAR(250),            
   @c_Sparm6            NVARCHAR(250),            
   @c_Sparm7            NVARCHAR(250),            
   @c_Sparm8            NVARCHAR(250),            
   @c_Sparm9            NVARCHAR(250),            
   @c_Sparm10           NVARCHAR(250),      
   @b_debug             INT = 0                       
)                    
AS                    
BEGIN                    
   SET NOCOUNT ON               
   SET ANSI_NULLS OFF              
   SET QUOTED_IDENTIFIER OFF               
   SET CONCAT_NULL_YIELDS_NULL OFF              

   DECLARE                
      @c_orderkey        NVARCHAR(10),
      @c_Storerkey       NVARCHAR(10),
      @n_copy            INT,
      @c_ExecStatements  NVARCHAR(4000),      
      @c_ExecArguments   NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000),
      @c_sql             NVARCHAR(MAX) ,
      @c_condition       NVARCHAR(4000)       

  DECLARE  @d_Trace_StartTime   DATETIME, 
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20), 
           @d_Trace_Step1      DATETIME, 
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @c_billtokey        NVARCHAR(20),
           @c_address          NVARCHAR(250),  
           @c_zip              NVARCHAR(250), 
           @c_staddress        NVARCHAR(250),  
           @c_stzip            NVARCHAR(250),
           @c_getorderkey      NVARCHAR(10),
           @c_sku              NVARCHAR(10),
           @c_getsdescr        NVARCHAR(250),
           @c_sdesc            NVARCHAR(250),
           @n_PQTY             INT

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''
      
    -- SET RowNo = 0           
   
    SET @n_copy = 0
    
    SET @n_copy = CAST (@c_Sparm4 AS INT)
          
            
    CREATE TABLE [#Result] (           
      [ID]    [INT] IDENTITY(1,1) NOT NULL,                          
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
    
      CREATE TABLE [#SKUContent] (                     
      [ID]                    [INT] IDENTITY(1,1) NOT NULL,
      [Pickslipno]            [NVARCHAR] (20)  NULL,
      [Orderkey]              [NVARCHAR] (20) NULL, 
      [SKU]                   [NVARCHAR] (20) NULL,                                    
      [SDESCR]                [NVARCHAR] (160) NULL,                                              
      [skuqty]                INT NULL,                             
      [Retrieve]              [NVARCHAR] (1) default 'N')       
    
  SET @c_SQLJOIN = +'SELECT DISTINCT orders.trackingno,orders.c_contact1,'
                   +' ISNULL(orders.c_company,''''), '
                   +' ISNULL(orders.c_phone2,''''),'''','           --5
                   +' '''','''','''','''','   --9
                   +' ISNULL(ST.b_company,''''),ISNULL(ST.b_phone1,''''),' --11
                   +' '''','
                   + ''''','
                   + ' '''','''','        --15
                   +' '''','
                   + ' ISNULL(orders.DeliveryNote,''''),'
                   + ' ISNULL(orders.Deliveryplace,''''),'
                   + ' convert(nvarchar(16),getdate(),121),'               --19
                   + ' ISNULL(C1.UDF01,''''), '                                                      --20
                   + ' '''',CASE WHEN orders.M_Country = ''GBP'' THEN ISNULL(C2.long, '''') ELSE Orders.M_Country END, '
                   + ' ISNULL(orders.userdefine01,''''),convert(nvarchar(10),DATEADD(DAY,1,getdate()),121),'
                   + ' ISNULL(orders.userdefine02,''''),'    --25                                                                  
                   +' '''','''',orders.Externorderkey,orders.orderkey,orders.notes,orders.notes2,ISNULL(ST.B_Phone2,''''),ISNULL(orders.c_phone1,''''),'''','''', '  --35     --CS01 --CS02
                   +' '''','''','''','''','''','''','''','''','''','''' ,'''','''','''','''','''','   --50
                   +' '''','''','''','''','''','''','''','''','''','''' '                              --60'
                   + ' FROM ORDERS orders WITH (NOLOCK) '
                   + ' JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = orders.storerkey '  
                   +' LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.LISTNAME=''SFHK'' ' 
                   +'                                     AND C1.Storerkey=orders.StorerKey '  
                   +' LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.LISTNAME=''CCODE'' ' 
                   +'                                     AND C2.Storerkey=orders.StorerKey '
                   +'                                     AND C2.short=orders.m_country'
                   + ' WHERE orders.loadkey =  @c_Sparm1 '                                            
                   + ' AND orders.orderkey = @c_Sparm2 '     
                   --+ ' AND orders.externorderkey not like ''TM%'' '
                   --+ ' AND orders.doctype = ''E'' and orders.facility = ''FN01'' '
                   --+ ' AND orders.C_Country in(''CN'',''HK'',''MO'',''TW'') '                           
                 
   IF @b_debug=1      
   BEGIN      
      PRINT @c_SQLJOIN        
   END              
            
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +         
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +         
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +         
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +         
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +         
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '        
  
   SET @c_SQL = @c_SQL + @c_SQLJOIN   + @c_condition   
         
 
   SET @c_ExecArguments = N'  @c_Sparm1         NVARCHAR(80)'  
                          + ' ,@c_Sparm2         NVARCHAR(80)'  
                          + ' ,@c_Sparm3         NVARCHAR(80)'  
                          + ' ,@c_Sparm4         NVARCHAR(80)'  
                                                             
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm1
                        , @c_Sparm2     
                        , @c_Sparm3    
                        , @c_Sparm4  
         
   IF @b_debug=1      
   BEGIN        
      PRINT @c_SQL        
   END      
   IF @b_debug=1      
   BEGIN      
      SELECT * FROM #Result (nolock)      
   END  
 
 DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                      
                     
   SELECT DISTINCT col29   
   FROM #Result                 
   ORDER BY col29          
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_orderkey
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN   

    SET @c_address = ''
   SET @c_zip= ''
   SET @c_staddress=''
   SET @c_stzip=''
   SET @c_Storerkey = ''
   SET @n_PQTY = 1
   SET @c_sdesc = ''

   SELECT @c_Storerkey = OH.Storerkey
         ,@c_address = (ISNULL(RTRIM(OH.c_address1),'') + SPACE(1) + ISNULL(RTRIM(OH.c_address2),'')+ SPACE(1) +ISNULL(RTRIM(OH.c_address3),'')+ SPACE(1) +ISNULL(RTRIM(OH.c_address4),'')+  SPACE(1)  )
         ,@c_zip = (ISNULL(RTRIM(OH.c_city),'') +  SPACE(1) + ISNULL(OH.c_state,'')+ SPACE(1) +ISNULL(OH.c_zip,'')+ SPACE(1) +ISNULL(OH.c_country,''))
   FROM ORDERS OH WITH (NOLOCK)
   WHERE Orderkey = @c_orderkey

   SELECT @c_staddress = (ISNULL(RTRIM(b_address1),'')+ SPACE(1) +ISNULL(RTRIM(b_address2),'')+ SPACE(1) +ISNULL(RTRIM(b_address3),'')+ SPACE(1) +ISNULL(RTRIM(b_address4),'') + SPACE(1) +ISNULL(RTRIM(b_city),'')+ SPACE(1) )
         ,@c_stzip = (ISNULL(b_state,'')+ SPACE(1) +ISNULL(b_zip,'')+ SPACE(1) +ISNULL(b_country,''))
   FROM STORER (NOLOCK)
   WHERE Storerkey = @c_Storerkey

      INSERT INTO [#SKUContent] (Pickslipno,orderkey,sku,SDESCR,skuqty,Retrieve)
      SELECT DISTINCT ph.pickslipno,ph.orderkey,pd.sku,s.notes1,sum(pd.qty),'N' 
      FROM packheader ph WITH (nolock)  
      JOIN packdetail pd WITH (nolock) on pd.pickslipno = ph.pickslipno
      JOIN sku s WITH (NOLOCK) ON S.StorerKey = pd.StorerKey and s.Sku = pd.SKU
      WHERE ph.storerkey = @c_Storerkey
      AND ph.OrderKey = @c_orderkey
      GROUP BY ph.pickslipno,ph.orderkey,pd.sku,s.notes1
      ORDER BY ph.pickslipno,ph.orderkey,pd.sku 

      SELECT @n_PQTY = SUM(skuqty)
      FROM [#SKUContent]
      WHERE Orderkey = @c_orderkey

       DECLARE CUR_RowPage CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
        SELECT DISTINCT Orderkey,SKU,SDESCR
        FROM [#SKUContent]
        Order by Orderkey,SKU

   OPEN CUR_RowPage            
            
   FETCH NEXT FROM CUR_RowPage INTO @c_getorderkey, @c_sku,@c_getsdescr
   WHILE @@FETCH_STATUS <> -1               
   BEGIN   

   IF @c_sdesc = ''
   BEGIN
      SET @c_sdesc = @c_getsdescr
   END
   ELSE
   BEGIN
     SET @c_sdesc = @c_sdesc + @c_getsdescr
   END
   

     FETCH NEXT FROM CUR_RowPage INTO  @c_getorderkey, @c_sku,@c_getsdescr           
            
      END -- While                     
      CLOSE CUR_RowPage                    
      DEALLOCATE CUR_RowPage

   UPDATE #Result
   SET col05 = substring(@c_address,1,80)
      ,col06 = substring(@c_address,81,80)
      ,col07 = substring(@c_address,161,80) 
      ,col08 = substring(@c_zip,1,80)
      ,col09 = substring(@c_zip,81,80)
      ,col12 = substring(@c_staddress,1,80)
      ,col13 = substring(@c_staddress,81,80)
      ,col14 = substring(@c_staddress,161,80)
      ,col15 = substring(@c_stzip,1,80)
      ,col16 = substring(@c_stzip,81,80)
      ,col21 = CAST(@n_PQTY as nvarchar(10))
      ,Col26 = substring(@c_sdesc,1,80)
      ,Col27 = substring(@c_sdesc,81,80)
   WHERE Col29 = @c_orderkey

   SET @c_sdesc = ''
       
  FETCH NEXT FROM CUR_RowNoLoop INTO  @c_orderkey               
            
      END -- While                     
      CLOSE CUR_RowNoLoop                    
      DEALLOCATE CUR_RowNoLoop 
EXIT_SP:  

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()
   
   --EXEC isp_InsertTraceInfo 
   --   @c_TraceCode = 'BARTENDER',
   --   @c_TraceName = 'isp_BT_Bartender_Shipper_Label_WAYBILL_AG',
   --   @c_starttime = @d_Trace_StartTime,
   --   @c_endtime = @d_Trace_EndTime,
   --   @c_step1 = @c_UserName,
   --   @c_step2 = '',
   --   @c_step3 = '',
   --   @c_step4 = '',
   --   @c_step5 = '',
   --   @c_col1 = @c_Sparm1, 
   --   @c_col2 = @c_Sparm2,
   --   @c_col3 = @c_Sparm3,
   --   @c_col4 = @c_Sparm4,
   --   @c_col5 = @c_Sparm5,
   --   @b_Success = 1,
   --   @n_Err = 0,
   --   @c_ErrMsg = ''            
 
select * from #result WITH (NOLOCK)
                                
END -- procedure  
 
 

GO