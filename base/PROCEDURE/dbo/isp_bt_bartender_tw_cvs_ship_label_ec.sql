SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: Copy from isp_BT_Bartender_TW_CVS_ship_Label_01                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-03-27 1.0  WLChooi    Created (WMS-12663)                             */ 
/******************************************************************************/                
             
CREATE PROC [dbo].[isp_BT_Bartender_TW_CVS_ship_Label_EC]                      
(  @c_Sparm01            NVARCHAR(250),              
   @c_Sparm02            NVARCHAR(250),              
   @c_Sparm03            NVARCHAR(250),              
   @c_Sparm04            NVARCHAR(250),              
   @c_Sparm05            NVARCHAR(250),              
   @c_Sparm06            NVARCHAR(250),              
   @c_Sparm07            NVARCHAR(250),              
   @c_Sparm08            NVARCHAR(250),              
   @c_Sparm09            NVARCHAR(250),              
   @c_Sparm10            NVARCHAR(250),        
   @b_debug              INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                                      
                              
   DECLARE                  
      @c_Uccno           NVARCHAR(20),                    
      @c_Sku             NVARCHAR(20),                         
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @n_totalcase       INT,
      @n_sequence        INT,
      @c_skugroup        NVARCHAR(10),
      @n_CntSku          INT,
      @n_TTLQty          INT,
      @c_col03           NVARCHAR(80),
      @c_col13           NVARCHAR(80),
      @c_col14           NVARCHAR(80),
      @c_col15           NVARCHAR(80),
      @c_col16           NVARCHAR(80),
      @c_col17           NVARCHAR(80),
      @c_col18           NVARCHAR(80),
      @c_getSec          NVARCHAR(80),
      @c_GetSec1         NVARCHAR(80),
      @c_GetSec2         NVARCHAR(80),
      @n_Sec1            INT,
      @n_Sec2            INT,
      @n_Sec1a           INT,
      @n_Sec2a           INT,
      @n_Sec1b           INT,
      @n_Sec2b           INT,
      @n_ModCol17        INT,   
      @n_ModCol18        INT,
      @c_Col08           NVARCHAR(80)        --(CS03)
          
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_ExecStatements   NVARCHAR(4000),  
           @c_ExecArguments    NVARCHAR(4000)         
         
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''  
    SET @c_Sku = '' 
    SET @c_skugroup = ''    
    SET @n_totalcase = 0  
    SET @n_sequence  = 1 
    SET @n_CntSku = 1  
    SET @n_TTLQty = 0     
    SET @c_col17 = ''
    SET @c_col18 = ''
    SET @c_GetSec1 = ''
    SET @c_GetSec2 = ''
              
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
                 
  SET @c_SQLJOIN = +N' SELECT DISTINCT o.Markforkey,substring(ISNULL(o.M_vat,''''),1,1),RIGHT(''00000000000''+CAST(o.orderkey AS VARCHAR(11)),11),substring(ISNULL(o.M_vat,''''),LEN(o.M_vat),1),'  + CHAR(13) +      --4
             + ' ISNULL(RTRIM(ST.company),''''),'  + CHAR(13) +
             + ' convert(varchar(10),(substring(convert(varchar(10),getdate()+2 ,  111),1,4)))+substring(convert(varchar(10),getdate()+2 ,  111),5,10),'  + CHAR(13) +  --6
             + ' ISNULL(o.C_contact1,''''),ISNULL(RTRIM(CL3.short),''''),ISNULL(CL3.UDF02,''''),ISNULL(CL1.description,''''),'  + CHAR(13) + --10       --(CS01)   
             + ' ISNULL(CL1.notes,''''), ISNULL(CL2.Short,''''), '  + CHAR(13) + --ISNULL(o.M_vat,''''),   --12 
             + ' o.externorderkey,ISNULL(CL3.UDF01,''''),CASE WHEN OI.OrderInfo03 = ''COD'' THEN ''1'' ELSE ''3'' END, '  + CHAR(13) + --15    
             + ' RIGHT(''00000'' + CAST(OI.PayableAmount AS NVARCHAR(5)), 5),'''','''', ' --18 
             + ' CONVERT(VARCHAR,(SUBSTRING(CONVERT(VARCHAR,GETDATE() + 9 , 111),1,4)))+SUBSTRING(CONVERT(VARCHAR,GETDATE() + 9 , 111),5,10) ,ISNULL(C.Short,''''),'  + CHAR(13) +     --20          
         --    + CHAR(13) +      
             + ' ISNULL(o.M_vat,''''),ISNULL(ST.SUSR1,''''),ISNULL(ST.SUSR2,''''),ISNULL(ST.SUSR3,''''),ISNULL(ST1.SUSR2,''''),ISNULL(ST1.SUSR3,''''), '  + CHAR(13) + --26 
             + ' ISNULL(ST1.SUSR4,''''),RIGHT(RTRIM(ISNULL(O.C_Phone1,'''')),3),ISNULL(C.Long,''''),SUBSTRING(O.Markforkey,2,6),'  + CHAR(13) +  --30  
             + ' '''','''','''','''','''','''','''','''','''','''', '  + CHAR(13) +   --40       
             + ' '''','''','''','''','''','''','''','''','''','''', '  + CHAR(13) +   --50       
             + ' '''','''','''','''','''','''','''','''','''','''' '   + CHAR(13) +    --60          
           --  + CHAR(13) +            
             + ' FROM ORDERS o WITH (NOLOCK) '   + CHAR(13) +
             + ' LEFT JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=o.Markforkey '  + CHAR(13) +              
             + ' LEFT JOIN Storer ST1 WITH (NOLOCK) ON ST1.storerkey=o.Storerkey '  + CHAR(13) +              
             + ' LEFT JOIN storersodefault SSO WITH (NOLOCK) ON SSO.storerkey=o.Markforkey '  + CHAR(13) +
             + ' LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON OI.Orderkey = o.Orderkey '  + CHAR(13) +
             + ' LEFT JOIN CODELKUP C   WITH (NOLOCK) ON listname = ''cvs_conv'' and C.Code=substring(o.M_vat,1,1) and C.storerkey = O.storerkey'  + CHAR(13) +   
             + ' LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.listname = ''WebsitInfo'' and CL1.Code=OI.Platform '  + CHAR(13) +  
             + ' LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.listname = ''CVSPAY'' and CL2.Code=case when o.type=''COD'' THEN ''1'' ELSE ''3'' END and CL2.storerkey = O.storerkey'  + CHAR(13) +  
             + ' LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON CL3.listname = ''carrierinf'' and CL3.Code=''CVS'' and CL3.storerkey = O.storerkey'  + CHAR(13) +
             + ' WHERE o.Loadkey = @c_Sparm02 '  + CHAR(13) +   
             + ' AND o.Orderkey =  @c_Sparm03 '  + CHAR(13) +    
             + ' AND o.Storerkey =  @c_Sparm01 '  + CHAR(13) +  
             + ' GROUP BY o.Markforkey,o.M_vat,RIGHT(''00000000000''+CAST(o.orderkey AS VARCHAR(11)),11),ISNULL(RTRIM(ST.company),''''), '  + CHAR(13) +      
             + ' ISNULL(o.C_contact1,''''),ISNULL(RTRIM(CL3.short),''''),ISNULL(CL3.UDF02,''''),'  + CHAR(13) +   
             + ' ISNULL(CL1.description,''''),ISNULL(CL1.notes,''''),o.externorderkey, '  + CHAR(13) +
             + ' RIGHT(''00000'' + CAST(OI.PayableAmount AS NVARCHAR(5)), 5), ISNULL(CL1.long,''''),ISNULL(CL2.short,''''), '  + CHAR(13) +  
             + ' CASE WHEN OI.OrderInfo03 = ''COD'' THEN ''1'' ELSE ''3'' END, ISNULL(C.Short,''''), ISNULL(CL3.UDF01,''''), '  + CHAR(13) +   
             + ' ISNULL(ST.SUSR1,''''),ISNULL(ST.SUSR2,''''),ISNULL(ST.SUSR3,''''),ISNULL(ST1.SUSR2,''''),ISNULL(ST1.SUSR3,''''), '  + CHAR(13) +
             + ' ISNULL(ST1.SUSR4,''''),RIGHT(RTRIM(ISNULL(O.C_Phone1,'''')),3),ISNULL(C.Long,''''),SUBSTRING(O.Markforkey,2,6) '   

   IF @b_debug=1        
   BEGIN        
      SELECT @c_SQLJOIN          
   END                
              
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             +',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
   SET @c_SQL = @c_SQL + @c_SQLJOIN     

   SET @c_ExecArguments = N'  @c_Sparm01      NVARCHAR(80)'    
                         + ', @c_Sparm02      NVARCHAR(80) '    
                         + ', @c_Sparm03      NVARCHAR(80) '   

                                          
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm01    
                        , @c_Sparm02      
                        , @c_Sparm03 
        
--EXEC sp_executesql @c_SQL          
        
   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL          
   END        

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT col03,col13 ,col14,col15,col16,Col08       
   FROM #Result               
   ORDER BY col03
          
   OPEN CUR_RowNoLoop                  
             
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_col03,@c_col13,@c_col14,@c_col15,@c_col16,@c_Col08  
               
   WHILE @@FETCH_STATUS <> -1             
   BEGIN  

      SET @c_GetSec1 = @c_col08 +substring(@c_col03,1,3) + @c_col14
      SET @c_GetSec2 = substring(@c_col03,4,8) + @c_col15 + @c_col16

      SET @c_getsec  =  @c_GetSec1 + @c_GetSec2
      
      SET @n_Sec1a = CONVERT(INT,SUBSTRING(@c_GetSec1,1,1)) + CONVERT(INT,SUBSTRING(@c_GetSec1,3,1)) + CONVERT(INT,SUBSTRING(@c_GetSec1,5,1))
                    + CONVERT(INT,SUBSTRING(@c_GetSec1,7,1))+ CONVERT(INT,SUBSTRING(@c_GetSec1,9,1)) + CONVERT(INT,SUBSTRING(@c_GetSec1,11,1))
                    + CONVERT(INT,SUBSTRING(@c_GetSec1,13,1))  
                    
      SET @n_Sec1b = CONVERT(INT,SUBSTRING(@c_GetSec2,1,1)) + CONVERT(INT,SUBSTRING(@c_GetSec2,3,1)) + CONVERT(INT,SUBSTRING(@c_GetSec2,5,1))
                    + CONVERT(INT,SUBSTRING(@c_GetSec2,7,1))+ CONVERT(INT,SUBSTRING(@c_GetSec2,9,1)) + CONVERT(INT,SUBSTRING(@c_GetSec2,11,1)) 
                    + CONVERT(INT,SUBSTRING(@c_GetSec2,13,1))  
                    
      SET @n_Sec2a = CONVERT(INT,SUBSTRING(@c_GetSec1,2,1)) + CONVERT(INT,SUBSTRING(@c_GetSec1,4,1)) + CONVERT(INT,SUBSTRING(@c_GetSec1,6,1))
                    + CONVERT(INT,SUBSTRING(@c_GetSec1,8,1))+ CONVERT(INT,SUBSTRING(@c_GetSec1,10,1)) + CONVERT(INT,SUBSTRING(@c_GetSec1,12,1))
                    + CONVERT(INT,SUBSTRING(@c_GetSec1,14,1))
      SET @n_Sec2b = CONVERT(INT,SUBSTRING(@c_GetSec2,2,1)) + CONVERT(INT,SUBSTRING(@c_GetSec2,4,1)) + CONVERT(INT,SUBSTRING(@c_GetSec2,6,1))
                    + CONVERT(INT,SUBSTRING(@c_GetSec2,8,1))+ CONVERT(INT,SUBSTRING(@c_GetSec2,10,1)) + CONVERT(INT,SUBSTRING(@c_GetSec2,12,1))
                    + CONVERT(INT,SUBSTRING(@c_GetSec2,14,1))
      
      SET @n_Sec1 = (@n_Sec1a + @n_Sec1b)
      
      SET @n_Sec2 = (@n_Sec2a + @n_Sec2b)

      IF @n_Sec1 % 11 = 0
      BEGIN
         SET @c_col17 = '0'
      END
      ELSE IF @n_Sec1 % 11 = 10
      BEGIN
         SET @c_col17 = '1'
      END
      ELSE
      BEGIN
         SET @c_col17 = @n_Sec1 % 11
      END   
      
      IF @n_Sec2 % 11 = 0
      BEGIN
         SET @c_col18= '8'
      END
      ELSE IF @n_Sec2%11 = 10
      BEGIN
         SET @c_col18 = '9'
      END
      ELSE
      BEGIN
         SET @c_col18= @n_Sec2 % 11
      END   
      
      UPDATE #Result
      SET col17 = @c_col17,
          col18 = @c_col18
      WHERE col03 = @c_col03
      
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_col03,@c_col13,@c_col14,@c_col15,@c_col16 ,@c_Col08         
        
   END -- While                   
   CLOSE CUR_RowNoLoop                  
   DEALLOCATE CUR_RowNoLoop     
                              
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_TW_CVS_ship_Label_EC',  
      @c_starttime = @d_Trace_StartTime,  
      @c_endtime = @d_Trace_EndTime,  
      @c_step1 = @c_UserName,  
      @c_step2 = '',  
      @c_step3 = '',  
      @c_step4 = '',  
      @c_step5 = '',  
      @c_col1 = @c_Sparm01,   
      @c_col2 = @c_Sparm02,  
      @c_col3 = @c_Sparm03,  
      @c_col4 = @c_Sparm04,  
      @c_col5 = @c_Sparm05,  
      @b_Success = 1,  
      @n_Err = 0,  
      @c_ErrMsg = ''              
   
   SELECT * FROM #Result (nolock) 
                                  
END -- procedure   



GO