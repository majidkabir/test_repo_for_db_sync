SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: BarTender Filter by ShipperKey                                    */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2014-06-21 1.0  CSCHONG    Created(SOS315751)                              */    
/* 2014-07-21 2.0  CSCHONG    Change the logic to add orderkey in filter(CS02)*/     
/* 2016-08-09 2.1  CSCHONG    Remove SET ANSI_WARNINGS OFF (CS03)             */        
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_Consolidation_Label]                       
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
  -- SET ANSI_WARNINGS OFF                 --(CS03)       
                              
   DECLARE                  
      @c_OrderKey        NVARCHAR(10),                    
      @c_ExternOrderKey  NVARCHAR(10),              
      @C_PDETnotes       NVARCHAR(4000)              
       
        
  DECLARE @n_RowNo             INT,  
          @c_SQL               NVARCHAR(4000),  
          @c_SQLSORT           NVARCHAR(4000),  
          @c_SQLJOIN           NVARCHAR(4000),  
          @n_cntPickzone       INT    
  
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20)     
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''        
      
              
    CREATE TABLE [#Result]  
    (  
     [ID]        [INT] IDENTITY(1, 1) NOT NULL,  
     [Col01]     [NVARCHAR] (80) NULL,  
     [Col02]     [NVARCHAR] (80) NULL,  
     [Col03]     [NVARCHAR] (80) NULL,  
     [Col04]     [NVARCHAR] (80) NULL,  
     [Col05]     [NVARCHAR] (80) NULL,  
     [Col06]     [NVARCHAR] (80) NULL,  
     [Col07]     [NVARCHAR] (80) NULL,  
     [Col08]     [NVARCHAR] (80) NULL,  
     [Col09]     [NVARCHAR] (80) NULL,  
     [Col10]     [NVARCHAR] (80) NULL,  
     [Col11]     [NVARCHAR] (80) NULL,  
     [Col12]     [NVARCHAR] (80) NULL,  
     [Col13]     [NVARCHAR] (80) NULL,  
     [Col14]     [NVARCHAR] (80) NULL,  
     [Col15]     [NVARCHAR] (80) NULL,  
     [Col16]     [NVARCHAR] (80) NULL,  
     [Col17]     [NVARCHAR] (80) NULL,  
     [Col18]     [NVARCHAR] (80) NULL,  
     [Col19]     [NVARCHAR] (80) NULL,  
     [Col20]     [NVARCHAR] (80) NULL,  
     [Col21]     [NVARCHAR] (80) NULL,  
     [Col22]     [NVARCHAR] (80) NULL,  
     [Col23]     [NVARCHAR] (80) NULL,  
     [Col24]     [NVARCHAR] (80) NULL,  
     [Col25]     [NVARCHAR] (80) NULL,  
     [Col26]     [NVARCHAR] (80) NULL,  
     [Col27]     [NVARCHAR] (80) NULL,  
     [Col28]     [NVARCHAR] (80) NULL,  
     [Col29]     [NVARCHAR] (80) NULL,  
     [Col30]     [NVARCHAR] (80) NULL,  
     [Col31]     [NVARCHAR] (80) NULL,  
     [Col32]     [NVARCHAR] (80) NULL,  
     [Col33]     [NVARCHAR] (80) NULL,  
     [Col34]     [NVARCHAR] (80) NULL,  
     [Col35]     [NVARCHAR] (80) NULL,  
     [Col36]     [NVARCHAR] (80) NULL,  
     [Col37]     [NVARCHAR] (80) NULL,  
     [Col38]     [NVARCHAR] (80) NULL,  
     [Col39]     [NVARCHAR] (80) NULL,  
     [Col40]     [NVARCHAR] (80) NULL,  
     [Col41]     [NVARCHAR] (80) NULL,  
     [Col42]     [NVARCHAR] (80) NULL,  
     [Col43]     [NVARCHAR] (80) NULL,  
     [Col44]     [NVARCHAR] (80) NULL,  
     [Col45]     [NVARCHAR] (80) NULL,  
     [Col46]     [NVARCHAR] (80) NULL,  
     [Col47]     [NVARCHAR] (80) NULL,  
     [Col48]     [NVARCHAR] (80) NULL,  
     [Col49]     [NVARCHAR] (80) NULL,  
     [Col50]     [NVARCHAR] (80) NULL,  
     [Col51]     [NVARCHAR] (80) NULL,  
     [Col52]     [NVARCHAR] (80) NULL,  
     [Col53]     [NVARCHAR] (80) NULL,  
     [Col54]     [NVARCHAR] (80) NULL,  
     [Col55]     [NVARCHAR] (80) NULL,  
     [Col56]     [NVARCHAR] (80) NULL,  
     [Col57]     [NVARCHAR] (80) NULL,  
     [Col58]     [NVARCHAR] (80) NULL,  
     [Col59]     [NVARCHAR] (80) NULL,  
     [Col60]     [NVARCHAR] (80) NULL  
    )            
      
    CREATE TABLE [#PICK]  
    (  
     [ID]             [INT] IDENTITY(1, 1) NOT NULL,  
     [OrderKey]       [NVARCHAR] (80) NULL,  
     [TTLPICKQTY]     [INT] NULL,  
     [PickZone]       [INT] NULL  
    )                
        
     SET @c_SQLJOIN = +' SELECT DISTINCT ORD.loadkey,ORD.orderkey,min(PD.notes)as notes,LOC.PickZone,'''','''','''','''','    --8        
                + CHAR(13) +           
                +''''','''','''','''','''','''','''','''','  --8       
                + CHAR(13) +          
                +''''','''','''','''','''','''','''','''','+ CHAR(13) +          
                +''''','''','''','''','''','''','''','''','          
                +''''','''','''','''','''','''','''','''','            
                + CHAR(13) +          
                +''''','''','''','           
                +''''','''','''','''','''','''','''', '  --50    
                +' '''','''','''','''','''','''','''','''','''','''' '         
                + CHAR(13) +            
                + ' FROM ORDERS ORD WITH (NOLOCK) ' --INNER JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  ON ORD.ORDERKEY = ORDDET.ORDERKEY   '       
               -- + ' INNER JOIN STORER STO WITH (NOLOCK) ON STO.STORERKEY = ORD.STORERKEY '        
                + ' INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = ORD.OrderKey'-- and PD.OrderLineNumber = ORDDET.OrderLineNumber'        
                + ' INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC '    --CS07      
                + ' WHERE ORD.LoadKey =''' + @c_Sparm1+ ''' '       
                + ' AND ORD.Orderkey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm3+ '''),'''') <> '''' THEN ''' + @c_Sparm3+ ''' ELSE ORD.Orderkey END'  --(CS02)  
                + ' AND LOC.PickZone = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm2+ '''),'''') <> '''' THEN ''' + @c_Sparm2+ ''' ELSE LOC.PickZone END'   
                + ' AND EXISTS (SELECT 1 FROM (SELECT ord1.loadkey,ord1.orderkey'  
                + ' FROM ORDERS ORD1 WITH (NOLOCK) JOIN PICKDETAIL PD1 WITH (NOLOCK) ON PD1.Orderkey = ORD1.orderkey'       
                + ' JOIN LOC LOC1 WITH (NOLOCK) ON LOC1.loc = PD1.Loc'  
                + ' WHERE ORD1.loadkey =''' + @c_Sparm1+ ''' '     
                + ' AND ORD1.orderkey =CASE WHEN ISNULL(RTRIM(''' + @c_Sparm3+ '''),'''') <> '''' THEN ''' + @c_Sparm3+ ''' ELSE ORD1.Orderkey END '     --(CS02)  
                + ' GROUP BY ord1.loadkey,ord1.orderkey'  
                + ' HAVING COUNT(DISTINCT LOC1.pickzone)>1) as t '    
                + ' WHERE t.loadkey = ORD.loadkey and t.orderkey=ord.orderkey)'  
                + ' GROUP BY Ord.loadkey,ord.orderkey,loc.pickzone'  
                + ' ORDER BY 4,3,2'  
  
      IF @b_debug = 1  
      BEGIN  
          PRINT @c_SQLJOIN  
      END               
              
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
   SET @c_SQL = @c_SQL + @c_SQLJOIN        
        
   EXEC sp_executesql @c_SQL          
        
   IF @b_debug = 1  
   BEGIN  
       PRINT @c_SQL  
   END  
  
   IF @b_debug = 1  
   BEGIN  
       SELECT *  
       FROM   #Result(NOLOCK)  
   END       
            
   /*DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
             
   SELECT DISTINCT col02 from #Result          
       
   OPEN CUR_RowNoLoop            
       
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey--,@c_Udef04         
         
   WHILE @@FETCH_STATUS <> -1            
   BEGIN           
         IF @b_debug='1'        
         BEGIN        
            PRINT @c_OrderKey           
         END        
  
    
       SELECT @C_PDETnotes        = MIN(PD.Notes),  
              @n_cntPickzone      = COUNT(DISTINCT l.pickzone)  
       FROM   PICKDETAIL PD(NOLOCK)  
       JOIN LOC L WITH (NOLOCK)  
                   ON  L.LOC = PD.LOC  
       WHERE  PD.OrderKey = @c_OrderKey  
     
      UPDATE #Result            
      SET Col03 = @C_PDETnotes        
      WHERE Col02=@c_OrderKey         
    
  
  INSERT INTO #PICK (OrderKey,TTLPICKQTY,PickZone)      
  VALUES (@c_OrderKey,'',ISNULL(@n_cntPickzone,0))  
  
   
  IF @b_Debug = '1'    
  BEGIN    
    SELECT 'Pick'  
    SELECT *    
    FROM   #PICK WITH (NOLOCK)    
  END    
    
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey--,@c_Udef04         
    
END -- While             
CLOSE CUR_RowNoLoop            
DEALLOCATE CUR_RowNoLoop  */          
  
     
         /*  SELECT R.*  
           FROM   #Result R WITH (NOLOCK)   
           INNER  JOIN #PICK P WITH (NOLOCK)  
                       ON  P.Orderkey = R.Col02  
           ORDER BY (CASE WHEN P.PickZone > 1 THEN col04 + col03 + col02 ELSE '1' END)*/  
  
       SELECT *  
       FROM   #Result WITH (NOLOCK)  
       ORDER BY Col04,Col03,Col02  
                      
                 
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_Consolidation_Label',  
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
                                    
END -- procedure   
  
   
  
  

GO