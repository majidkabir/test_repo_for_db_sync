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
/* 2018-10-30     1.0  CSCHONG    Created (WMS-6771)                          */              
/******************************************************************************/              
                
CREATE PROC [dbo].[isp_BT_Bartender_HK_WAYRTNBLBL_label]                     
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
          
    
    SET @c_condition = ''
    SET @c_billtokey = ''
    SET @c_notes = ''
     
    
  SET @c_SQLJOIN = +'SELECT DISTINCT ISNULL(orders.RTNTrackingNo,''''),ST.b_company,'
                   +' '''', '
                   +'orders.c_phone1,'''','           --5
                   +' orders.c_contact1,'''',ST.b_phone1,'''','   --9
                   +' orders.Externorderkey,substring(ISNULL(C2.notes,''''),1,80),' --11
                   +' substring(ISNULL(C2.notes2,''''),1,80),'
                 --+ 'replace(convert(nvarchar(11),PH.editdate,113),'' '',''/''),'
                   + ' '''', '''','''', ' 
                -- + ' replace(convert(nvarchar(11),DATEADD(DAY,1,PH.editdate),113),'' '',''/''),'''','        --15
                   +' replace(convert(nvarchar(11),DATEADD(DAY,30,PH.editdate),113),'' '',''/''),'
                   + ' substring(ISNULL(C2.UDF03,''''),1,80),'
                   + ' ISNULL(ST.B_address1,'''') ,'
                 --+ ' ELSE ISNULL(orders.c_address2,'''') END,'
                   + ' ISNULL(ST.B_address2,''''),'
                -- + ' ELSE ISNULL(orders.c_address3,'''') END,'
                   + ' ISNULL(ST.B_address3,''''),'
                   + ' CASE WHEN C1.short=''2'' THEN (ISNULL(orders.c_address1,'''') + ISNULL(orders.c_address2,'''') )'              --21
                   + ' ELSE ISNULL(orders.c_address2,'''') END,'
                   + ' CASE WHEN C1.short=''2'' THEN (ISNULL(orders.c_address3,'''') + ISNULL(orders.c_address4,'''') )'              --22
                   + ' ELSE ISNULL(orders.c_address3,'''') END,'
                   + ' CASE WHEN C1.short=''2'' THEN (ISNULL(orders.c_city,'''') + space(2) + ISNULL(orders.c_zip,'''') + space(2) +'
                   + ' ISNULL(orders.c_country,'''')) ELSE (ISNULL(orders.c_address4,'''')+ space(2) +ISNULL(orders.c_address1,'''')) END,'     --20
                   + ' '''','''','    --25                                                                  
                   +' '''','''','''','''','''','''','''','''','''','''', '  --35  
                   +' '''','''','''','''','''','''','''','''','''','''' ,'''','''','''','''','''','   --50
                   +' '''','''','''','''','''','''','''','''','''','''' '                              --60'
                   + ' FROM ORDERS orders WITH (NOLOCK) '
                   + ' JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = orders.storerkey ' 
                   + ' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = orders.orderkey'
                   +' LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.LISTNAME=''COUR_RTPREF'' ' 
                   +'                                     AND C1.Storerkey=orders.StorerKey AND C1.Code2=''YMTHK'' '   
                   +' LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.LISTNAME=''YMTRT_PREF'' ' 
                   +'                                     AND C2.Storerkey=orders.StorerKey '  
                   + ' WHERE orders.StorerKey =  @c_Sparm1 '                                            
                   + ' AND orders.orderkey = @c_Sparm2 '                               
                 
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

EXIT_SP:  

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()
   
   EXEC isp_InsertTraceInfo 
      @c_TraceCode = 'BARTENDER',
      @c_TraceName = 'isp_BT_Bartender_HK_WAYRTNBLBL_label',
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