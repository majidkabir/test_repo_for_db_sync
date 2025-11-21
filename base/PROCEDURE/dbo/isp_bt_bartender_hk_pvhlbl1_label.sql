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
/* 25-Apr-2018    1.0  CSCHONG    WMS-4647 Created                            */    
/* 11-JUN-2018    1.1  CSCHONG    WMS-5391 revised field mapping (CS01)       */  
/* 17-JUL-2018    1.2  CSCHONG    WMS-5610 - add new field (CS02)             */ 
/* 08-Nov-2018    1.3  CSCHONG    WMS-5610 - reposition field printing (CS03) */    
/* 13-AUG-2020    1.4  CSCHONG    WMS-14729 - revised field mapping (CS04)    */     
/******************************************************************************/              
                
CREATE PROC [dbo].[isp_BT_Bartender_HK_PVHLBL1_label]                     
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
      @c_labelno         NVARCHAR(10),
      @n_copy            INT,
      @c_ExecStatements  NVARCHAR(4000),      
      @c_ExecArguments   NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000),
      @c_sql             NVARCHAR(MAX) ,
      @c_condition       NVARCHAR(4000)       

  DECLARE @d_Trace_StartTime   DATETIME, 
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20), 
           @d_Trace_Step1      DATETIME, 
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @c_billtokey        NVARCHAR(20),
           @c_notes            NVARCHAR(250)   

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
    

     --CREATE TABLE [#CartonContent] (           
     -- [ID]          [INT] IDENTITY(1,1) NOT NULL,                          
     -- [DUdef10]     [NVARCHAR] (20) NULL, 
     -- [DUdef03]     [NVARCHAR] (20) NULL,   
     -- [itemclass]   [NVARCHAR] (10) NULL,  
     -- [skugroup]    [NVARCHAR] (10) NULL,   
     -- [style]       [NVARCHAR] (20) NULL,         
     -- [TTLPICKQTY]  [INT] NULL)   

    --CREATE TABLE [#COO] (           
    --  [ID]          [INT] IDENTITY(1,1) NOT NULL,                          
    --  [Lottable03]  [NVARCHAR] (80) NULL)           
    
    SET @c_condition = ''
    SET @c_billtokey = ''
    SET @c_notes = ''
   --CS03 start
   INSERT INTO #Result(Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09,Col10,
                           Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,
                           Col21,Col22,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,
                           Col31,Col32,Col33,Col34,Col35,Col36,Col37,Col38,Col39,Col40,
                           Col41,Col42,Col43,Col44,Col45,Col46,Col47,Col48,Col49,Col50,
                           Col51,Col52,Col53,Col54,Col55,Col56,Col57,Col58,Col59,Col60)
       VALUES('','','','','','','','','','',
              @c_Sparm2,'','','','','','','','','',
              '','','','','','','','','','',
              '','','','','','','','','','',
              '','','','','','','','','','', 
              '','','','','','','','','','') 

    INSERT INTO #Result(Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09,Col10,
                           Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,
                           Col21,Col22,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,
                           Col31,Col32,Col33,Col34,Col35,Col36,Col37,Col38,Col39,Col40,
                           Col41,Col42,Col43,Col44,Col45,Col46,Col47,Col48,Col49,Col50,
                           Col51,Col52,Col53,Col54,Col55,Col56,Col57,Col58,Col59,Col60)
   SELECT TOP 1 '',s.style,'',s.color,'', s.size,'','','','',
                '',@c_Sparm3,'','','','','','','','',
                '','','','','','','','','','',
               '','','','','','','','','','',
               '','','','','','','','','','', 
               '','','','','','','','','',''
   FROM sku s
   where s.storerkey = @c_Sparm1 
   and s.sku=@c_Sparm3

    --CS03 End

    SELECT DISTINCT @c_billtokey   =  billtokey 
    FROM orders WITH (NOLOCK) 
    where orderkey in (
    select orderkey from pickdetail WITH (NOLOCK)  where pickslipno in (select pickslipno 
    from packdetail WITH (NOLOCK)  where storerkey = @c_Sparm1 and sku = @c_Sparm3 and labelno=@c_Sparm2)) 
    
    
    SELECT @c_notes = notes
    FROM CODELKUP WITH (NOLOCK) 
    WHERE LISTNAME='PVHPXLBL'
    AND code = @c_billtokey
    
   -- SELECT @c_notes '@c_notes'
    IF ISNULL(@c_notes,'') <> ''
    BEGIN
      SET @c_condition = ' AND ' + @c_notes
    END      
    
  SET @c_SQLJOIN = +'SELECT DISTINCT @c_Sparm4,SKU.Style,SKU.BUSR1,SKU.Color,SKU.Measurement,'
                   +' SKU.[Size],Right(SKU.class,2) + Right(SKU.Itemclass,3),ISNULL(OD.Userdefine02,''''),'       --CS01  --CS04
                   + ' CASE WHEN orders.B_Country IN (''SG'',''MY'',''CN'',''HK'',''MO'') THEN '
                   +  ' CONVERT(NVARCHAR(10),CAST(OD.tax01 AS Decimal(10,2))) ELSE CONVERT(NVARCHAR(10),CAST(OD.tax01 AS Decimal(10,0)))  END,'   --9 --CS04
                   +' ISNULL(C2.Short,''''),'''','''','''','''','''','        --15
                   +' '''','''','''','''','''','      --20
                  -- +' '''','''','''','''','''','    --25                                                                  
                   +' '''' ,'''','''','''','''','''','''','''','''','''','''','''','''','''','''', '  --35  
                   +' '''','''','''','''','''','''','''','''','''','''' ,'''','''','''','''','''','   --50
                   +' '''','''','''','''','''','''','''','''','''','''' '                              --60
               --    +' FROM PACKDETAIL PD WITH (NOLOCK) '
                 --  +' JOIN packheader ph WITH (NOLOCK) ON ph.PickSlipNo=pd.PickSlipNo '
                   +' FROM PICKDETAIL PID WITH (NOLOCK) '-- ON PID.CaseID=PD.LabelNo'
                   +' JOIN SKU SKU WITH (NOLOCK) ON SKU.StorerKey=PID.StorerKey AND SKU.sku = PID.SKU'
                   + ' JOIN ORDERDETAIL OD WITH (NOLOCK) ON od.orderkey=PID.orderkey AND od.sku=PID.sku '
                   + ' AND od.OrderLineNumber=PID.OrderLineNumber  '
                   + ' JOIN ORDERS orders WITH (NOLOCK) ON orders.OrderKey=od.OrderKey '
                   --+' LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.LISTNAME=''PVHCURR'' '                                                --CS04
                   --+'                                     AND C1.Storerkey=orders.StorerKey AND C1.Code=orders.B_Country'
                   +' LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.LISTNAME=''PVHPXLBL'' '
                   +'                                     AND C2.Storerkey=orders.StorerKey AND C2.Code=orders.BillToKey '    
                   + ' WHERE PID.StorerKey =  @c_Sparm1 '                                            
                   + ' AND PID.caseid = @c_Sparm2 '  
                   + ' AND PID.sku = @c_Sparm3'                               
                 
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
         
   --EXEC sp_executesql @c_SQL        
   
  -- SELECT @c_SQL  '@c_SQL' 
   
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
   
   
   WHILE @n_copy > 1
   BEGIN
      INSERT INTO #Result
      (
         -- ID -- this column value is auto-generated
         Col01,
         Col02,
         Col03,
         Col04,
         Col05,
         Col06,
         Col07,
         Col08,
         Col09,
         Col10,
         Col11,
         Col12,
         Col13,
         Col14,
         Col15,
         Col16,
         Col17,
         Col18,
         Col19,
         Col20,
         Col21,
         Col22,
         Col23,
         Col24,
         Col25,
         Col26,
         Col27,
         Col28,
         Col29,
         Col30,
         Col31,
         Col32,
         Col33,
         Col34,
         Col35,
         Col36,
         Col37,
         Col38,
         Col39,
         Col40,
         Col41,
         Col42,
         Col43,
         Col44,
         Col45,
         Col46,
         Col47,
         Col48,
         Col49,
         Col50,
         Col51,
         Col52,
         Col53,
         Col54,
         Col55,
         Col56,
         Col57,
         Col58,
         Col59,
         Col60
      )
      SELECT TOP 1 Col01,
         Col02,
         Col03,
         Col04,
         Col05,
         Col06,
         Col07,
         Col08,
         Col09,
         Col10,
         Col11,
         Col12,
         Col13,
         Col14,
         Col15,
         Col16,
         Col17,
         Col18,
         Col19,
         Col20,
         Col21,
         Col22,
         Col23,
         Col24,
         Col25,
         Col26,
         Col27,
         Col28,
         Col29,
         Col30,
         Col31,
         Col32,
         Col33,
         Col34,
         Col35,
         Col36,
         Col37,
         Col38,
         Col39,
         Col40,
         Col41,
         Col42,
         Col43,
         Col44,
         Col45,
         Col46,
         Col47,
         Col48,
         Col49,
         Col50,
         Col51,
         Col52,
         Col53,
         Col54,
         Col55,
         Col56,
         Col57,
         Col58,
         Col59,
         Col60
         FROM #Result AS r
         where isnull(Col01,'') <> ''
      ORDER BY r.ID
      
      SET @n_copy = @n_copy - 1
   END




EXIT_SP:  

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()
   
   EXEC isp_InsertTraceInfo 
      @c_TraceCode = 'BARTENDER',
      @c_TraceName = 'isp_BT_Bartender_HK_PVHLBL1_label',
      @c_starttime = @d_Trace_StartTime,
      @c_endtime = @d_Trace_EndTime,
      @c_step1 = @c_UserName,
      @c_step2 = '',
      @c_step3 = '',
      @c_step4 = '',
      @c_step5 = '',
      @c_col1 = @c_Sparm1, 
      @c_col2 = @c_Sparm2,
      @c_col3 = @c_Sparm3,
      @c_col4 = @c_Sparm4,
      @c_col5 = @c_Sparm5,
      @b_Success = 1,
      @n_Err = 0,
      @c_ErrMsg = ''            
 
select * from #result WITH (NOLOCK)
                                
END -- procedure  
 
 

GO