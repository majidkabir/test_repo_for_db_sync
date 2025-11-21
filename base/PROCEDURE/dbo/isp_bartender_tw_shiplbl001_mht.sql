SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
    
/******************************************************************************/                     
/* Copyright: IDS                                                             */                     
/* Purpose: isp_Bartender_TW_SHIPLBL001_MHT                                   */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */                     
/* 2019-04-12 1.0  CSCHONG    Created (WMS-8086)                              */     
/******************************************************************************/                    
                      
CREATE PROC [dbo].[isp_Bartender_TW_SHIPLBL001_MHT]                          
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
      @c_dropid          NVARCHAR(30),                        
      @c_Sku             NVARCHAR(20),                             
      @n_intFlag         INT,         
      @n_CntRec          INT,        
      @c_SQL             NVARCHAR(4000),            
      @c_SQLSORT         NVARCHAR(4000),            
      @c_SQLJOIN         NVARCHAR(4000),    
      @n_totalcase       INT,    
      @n_sequence        INT,    
      @c_skugroup        NVARCHAR(10),    
      @n_CPLT            INT,    
      @n_CSQty           INT,    
      @n_TTLPLT          INT,    
      @c_ExecStatements   NVARCHAR(4000),       
      @c_ExecArguments    NVARCHAR(4000),    
      @c_orderkey         NVARCHAR(20),    
      @c_storerkey        NVARCHAR(20),    
      @c_consigneekey     NVARCHAR(20),    
      @c_col04            NVARCHAR(80),    
      @c_col06            NVARCHAR(80),    
      @c_col07            NVARCHAR(80),    
      @c_col08            NVARCHAR(80),    
      @n_ppaqty           FLOAT,    
      @c_UDF02            NVARCHAR(20),    
      @c_UDF03            NVARCHAR(20),    
      @d_MDate            DATETIME,    
      @n_shelflife        INT,    
      @d_lottable04       DATETIME,    
      @n_Getshelflife     INT,    
      @n_Col07            INT    
              
        
  DECLARE  @d_Trace_StartTime   DATETIME,       
           @d_Trace_EndTime    DATETIME,      
           @c_Trace_ModuleName NVARCHAR(20),       
           @d_Trace_Step1      DATETIME,       
           @c_Trace_Step1      NVARCHAR(20),      
           @c_UserName         NVARCHAR(20)         
      
   SET @d_Trace_StartTime = GETDATE()      
   SET @c_Trace_ModuleName = ''      
            
    -- SET RowNo = 0                 
    SET @c_SQL = ''      
    SET @c_Sku = ''     
    SET @c_skugroup = ''        
    SET @n_totalcase = 0      
    SET @n_sequence  = 1     
    SET @n_CPLT = 1      
    SET @n_CSQty = 0         
    SET @n_TTLPLT = 1    
                  
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
         
     CREATE TABLE #TEMPPDDROPID (    
     RowID INT IDENTITY(1,1) NOT NULL,     
     Orderkey NVARCHAR(20) NULL,    
     Dropid   NVARCHAR(20) NULL     
     )    
                  
                
  SET @c_SQLJOIN = +N' SELECT DISTINCT PD.Dropid,ISNULL(ST.company,''''),SUM(PD.Qty),'''','''','       --5    
             + ' ORD.Orderkey,ORD.externOrderkey,CONVERT(NVARCHAR(10),ORD.deliverydate,101),ORD.c_company,'  --9  
             + ' LP.Externloadkey,LP.TrfRoom,ORD.Route,SSO.Route,'''','''',' --15                 --(CS02)        
             + ' '''','''','''','''','''','     --20           
         --    + CHAR(13) +          
             + ' '''','''','''','''','''','''','''','''','''','''','  --30      
             + ' '''','''','''','''','''','''','''','''','''','''','   --40           
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50           
             + ' '''','''','''','''','''','''','''','''',ORD.storerkey,''TW'' '   --60              
           --  + CHAR(13) +                
             + ' FROM ORDERS ORD WITH (NOLOCK)'           
             + ' JOIN OrderDetail ORDDET WITH (NOLOCK) ON ORDDET.orderkey=ORD.Orderkey'    
             + ' JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = ORD.Storerkey '     
             + ' LEFT JOIN StorerSODefault SSO WITH (NOLOCK) ON SSO.storerkey = ORD.consigneekey'      
             + ' LEFT JOIN LOADPLAN LP WITH (NOLOCK) ON LP.loadkey=ORD.loadkey'       
             + ' JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.orderkey = ORD.Orderkey '     
             + ' WHERE PD.Orderkey =@c_Sparm02 '       
             + ' AND PD.dropid = @c_Sparm01'  
             + ' GROUP BY PD.Dropid,ISNULL(ST.company,''''),ORD.Orderkey,ORD.externOrderkey,ORD.storerkey, '  
             + ' CONVERT(NVARCHAR(10),ORD.deliverydate,101),ORD.c_company,LP.Externloadkey,LP.TrfRoom,ORD.Route,SSO.Route '     
              
IF @b_debug=1            
BEGIN            
   SELECT @c_SQLJOIN              
END                   
                  
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +               
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +               
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +               
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +               
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +               
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '              
        
SET @c_SQL = @c_SQL + @c_SQLJOIN            
            
--EXEC sp_executesql @c_SQL              
    
  SET @c_ExecArguments = N'    @c_Sparm01           NVARCHAR(80)'          
                          + ', @c_Sparm02           NVARCHAR(80)'       
                          + ', @c_Sparm04           NVARCHAR(80) '        
                          + ', @c_Sparm05           NVARCHAR(80)'      
                          + ', @c_Sparm06           NVARCHAR(80)'      
                             
                             
   EXEC sp_ExecuteSql     @c_SQL         
                        , @c_ExecArguments        
                        , @c_Sparm01         
                        , @c_Sparm02    
                        , @c_Sparm04    
                        , @c_Sparm05      
                        , @c_Sparm06    
            
   IF @b_debug=1            
   BEGIN              
      PRINT @c_SQL              
   END            
   IF @b_debug=1            
   BEGIN            
      SELECT * FROM #Result (nolock)            
   END            
    
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                             
   SELECT DISTINCT Col01,Col06,col59 FROM #Result              
           
   OPEN CUR_RowNoLoop                
           
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_dropid,@c_orderkey,@c_storerkey        
             
   WHILE @@FETCH_STATUS <> -1                
   BEGIN       
       
  INSERT INTO #TEMPPDDROPID    
  (    
   -- RowID -- this column value is auto-generated    
   Orderkey,    
   Dropid    
  )    
 SELECT DISTINCT  PD.OrderKey,PD.DropID    
 FROM PICKDETAIL PD WITH (NOLOCK)    
 WHERE PD.OrderKey = @c_orderkey    
 AND PD.Storerkey = @c_storerkey   
 AND ISNULL(PD.Dropid,'') <> ''   
 ORDER BY pd.DropID    
     
     
 SET @n_TTLPLT = 1    
     
 SELECT @n_TTLPLT = COUNT(DISTINCT Dropid)    
 FROM #TEMPPDDROPID     
 WHERE Orderkey = @c_orderkey    
     
 SELECT @n_CPLT =RowID    
 FROM #TEMPPDDROPID    
 WHERE Dropid = @c_dropid    
    
   UPDATE #Result    
   SET Col04 = convert(nvarchar(10),@n_TTLPLT),    
       Col05 = convert(nvarchar(10),@n_CPLT)   
       FETCH NEXT FROM CUR_RowNoLoop INTO @c_dropid,@c_orderkey,@c_storerkey         
   END -- While                 
   CLOSE CUR_RowNoLoop                
   DEALLOCATE CUR_RowNoLoop                      
           
                
EXIT_SP:        
      
   SET @d_Trace_EndTime = GETDATE()      
   SET @c_UserName = SUSER_SNAME()      
         
   EXEC isp_InsertTraceInfo       
      @c_TraceCode = 'BARTENDER',      
      @c_TraceName = 'isp_Bartender_TW_SHIPLBL001_MHT',      
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
    
    
DROP TABLE #TEMPPDDROPID                                      
END -- procedure  

GO