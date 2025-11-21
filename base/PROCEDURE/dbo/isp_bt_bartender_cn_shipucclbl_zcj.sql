SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/********************************************************************************/                   
/* Copyright: LFL                                                               */                   
/* Purpose: isp_BT_Bartender_CN_SHIPUCCLBL_ZCJ                                  */                   
/*                                                                              */                   
/* Modifications log:                                                           */                   
/*                                                                              */                   
/* Date       Rev  Author     Purposes                                          */      
/* 2022-04-22 1.0  CHONGCS    Devops Scripts Combine                            */         
/* 2022-04-22 1.0  CHONGCS    Created (WMS-19483)                               */  
/********************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_CN_SHIPUCCLBL_ZCJ]                        
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
   --SET ANSI_WARNINGS OFF                    
                                
   DECLARE                    
      @c_ReceiptKey      NVARCHAR(10),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_ExecStatements  NVARCHAR(4000),         
      @c_ExecArguments   NVARCHAR(4000),     
      @c_SKU01           NVARCHAR(80),    
      @c_loc01           NVARCHAR(80),   
      @c_Qty01           NVARCHAR(80),  
      @c_ExpDate01       NVARCHAR(10),
  
      @c_SKU02           NVARCHAR(80),    
      @c_loc02           NVARCHAR(80),   
      @c_Qty02           NVARCHAR(80),  
      @c_ExpDate02       NVARCHAR(10),     
  
      @c_SKU03           NVARCHAR(80),    
      @c_loc03           NVARCHAR(80),   
      @c_Qty03           NVARCHAR(80),  
      @c_ExpDate03       NVARCHAR(10),  

      @c_SKU04           NVARCHAR(80),    
      @c_loc04           NVARCHAR(80),   
      @c_Qty04           NVARCHAR(80), 
      @c_ExpDate04       NVARCHAR(10), 
  
      @c_SKU05           NVARCHAR(80),    
      @c_loc05           NVARCHAR(80),   
      @c_Qty05           NVARCHAR(80),  
      @c_ExpDate05       NVARCHAR(10),      

      @c_SKU06           NVARCHAR(80),    
      @c_loc06           NVARCHAR(80),   
      @c_Qty06           NVARCHAR(80), 
      @c_ExpDate06       NVARCHAR(10),
      
      @c_SKU07           NVARCHAR(80),    
      @c_loc07           NVARCHAR(80),   
      @c_Qty07           NVARCHAR(80), 
      @c_ExpDate07       NVARCHAR(10),
      
      @c_SKU08           NVARCHAR(80),    
      @c_loc08           NVARCHAR(80),   
      @c_Qty08           NVARCHAR(80), 
      @c_ExpDate08       NVARCHAR(10),
      
      @c_SKU09           NVARCHAR(80),    
      @c_loc09           NVARCHAR(80),   
      @c_Qty09           NVARCHAR(80), 
      @c_ExpDate09       NVARCHAR(10),
      
      @c_SKU10           NVARCHAR(80),    
      @c_loc10           NVARCHAR(80),   
      @c_Qty10           NVARCHAR(80), 
      @c_ExpDate10       NVARCHAR(10),
  
      @c_SKU             NVARCHAR(80),  
      @c_loc             NVARCHAR(80),  
      @c_Qty             NVARCHAR(80),  
      @c_ExpDate         NVARCHAR(10),
        
      @c_CheckConso      NVARCHAR(10),  
      @c_GetOrderkey     NVARCHAR(10),  
        
      @n_TTLpage         INT,            
      @n_CurrentPage     INT,    
      @n_MaxLine         INT,  
        
      @c_LabelNo            NVARCHAR(30),  
      @c_Pickslipno         NVARCHAR(10),  
      @c_CartonNo           NVARCHAR(10),  
      @n_SumQty             INT,  
      @c_Sorting            NVARCHAR(4000),  
      @c_ExtraSQL           NVARCHAR(4000),  
      @c_JoinStatement      NVARCHAR(4000),
      @c_AllExtOrderkey     NVARCHAR(80) = '',    
      @c_Col10              NVARCHAR(80) = '',   
      @c_Col04              NVARCHAR(80) = '',      
      @c_Col03              NVARCHAR(80) = '',   
      @c_Col05              NVARCHAR(80) = '',    
      @c_Col06              NVARCHAR(80) = '',   
      @c_Col07              NVARCHAR(80) = '',   
      @c_Col08              NVARCHAR(80) = '', 
      @c_Col44              NVARCHAR(80) = '', 
      @c_Storerkey          NVARCHAR(15) = '',
      @n_TTLPADQTY          INT = 0  ,
      @n_TTLCTN             INT = 0      
          

  DECLARE  @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20)       
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''   
     
   SET @n_CurrentPage = 1    
   SET @n_TTLpage = 1         
   SET @n_MaxLine = 10        
   SET @n_CntRec = 1      
   SET @n_intFlag = 1    
   SET @c_ExtraSQL = ''  
   SET @c_JoinStatement = ''  
  
   SET @c_CheckConso = 'N'  
      
-- SET RowNo = 0               
   SET @c_SQL = ''         

   --Discrete  
   SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey, 
                @c_Col10       = ISNULL(ORDERS.Notes,''),  
                @c_Col04       = LTRIM(RTRIM(ISNULL(ORDERS.c_contact1,''))),   
                @c_Col03       = CASE WHEN ORDERS.ordergroup='VIP'   THEN ISNULL(ST.Company,'')
                                     ELSE ORDERS.C_Company END,  
                @c_Col05       = LTRIM(RTRIM(ISNULL(ORDERS.c_phone1,''))),   
                @c_Col06       = LTRIM(RTRIM(ISNULL(ORDERS.C_State,''))),   
                @c_Col07       = LTRIM(RTRIM(ISNULL(ORDERS.c_city,''))),
                @c_col08       =   LEFT(LTRIM(RTRIM(ISNULL(ORDERS.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Address2,''))) 
                                  + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Address3,'')))+ ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Address4,''))),80),
                @c_col44  =    LTRIM(RTRIM(ISNULL(ORDERS.ordergroup,''))),
                @c_Storerkey   = ORDERS.Storerkey  
   FROM PACKHEADER (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY  
   LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = ORDERS.consigneekey AND ST.type='2'
   WHERE PACKHEADER.Pickslipno = @c_Sparm01  

  
   IF ISNULL(@c_GetOrderkey,'') = ''  
   BEGIN  
      --Conso  
      SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey,
                   @c_Col10       = ISNULL(ORDERS.Notes,''),  
                   @c_Col04       = LTRIM(RTRIM(ISNULL(ORDERS.c_contact1,''))),   
                   @c_Col03       = CASE WHEN ORDERS.ordergroup='VIP'   THEN ISNULL(ST.Company,'')
                                     ELSE ORDERS.C_Company END,     
                   @c_Col05       = LTRIM(RTRIM(ISNULL(ORDERS.c_phone1,''))),   
                   @c_Col06       = LTRIM(RTRIM(ISNULL(ORDERS.C_State,''))),  
                   @c_Col07       = LTRIM(RTRIM(ISNULL(ORDERS.c_city,''))),   
                   @c_col08       =   LEFT(LTRIM(RTRIM(ISNULL(ORDERS.C_Address1,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Address2,''))) 
                                  + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Address3,'')))+ ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Address4,''))),80),
                   @c_col44  =    LTRIM(RTRIM(ISNULL(ORDERS.ordergroup,''))),
                   @c_Storerkey   = ORDERS.Storerkey  
      FROM PACKHEADER (NOLOCK)  
      JOIN LOADPLANDETAIL (NOLOCK) ON PACKHEADER.LOADKEY = LOADPLANDETAIL.LOADKEY  
      JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY  
      JOIN STORER ST (NOLOCK) ON ST.StorerKey = ORDERS.consigneekey AND ST.type='2'
      WHERE PACKHEADER.Pickslipno = @c_Sparm01  

  
      IF ISNULL(@c_GetOrderkey,'') <> ''  
         SET @c_CheckConso = 'Y'  
      ELSE  
         GOTO EXIT_SP  
   END  
   
   SET @c_JoinStatement = N' JOIN ORDERS OH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY ' + CHAR(13)  
     
   IF @c_CheckConso = 'Y'  
   BEGIN  
      SET @c_JoinStatement = N' JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.LOADKEY = LPD.LOADKEY ' + CHAR(13)  
                            + ' JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = LPD.ORDERKEY ' + CHAR(13)  
   END  
   

      SELECT @c_AllExtOrderkey = MAX(OH.ExternOrderkey)
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.Orderkey
      WHERE PH.PickSlipNo = @c_Sparm01

   SELECT @c_Col10 = LEFT(LTRIM(RTRIM(@c_Col10)), 80)

     
   IF @b_debug = 1     
      SELECT @c_CheckConso       
                
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
        
      CREATE TABLE #Temp_Packdetail (  
       [ID]              [INT] IDENTITY(1,1) NOT NULL,         
       [Pickslipno]      [NVARCHAR] (80) NULL,  
       [ExpDate]         [NVARCHAR] (10) NULL,  
       [CartonNo]        [NVARCHAR] (80) NULL,    
       [caseid]          [NVARCHAR] (20) NULL,                               
       [SKU]             [NVARCHAR] (80) NULL, 
       [SDESCR]          [NVARCHAR] (80) NULL, 
       [loc]             [NVARCHAR] (80) NULL,  
       [Qty]             [NVARCHAR] (80) NULL,  
       [Retreive]        [NVARCHAR] (80) NULL  
      )           
  
      SET @c_Sorting = N' ORDER BY PH.Pickslipno, PD.CartonNo DESC '  
  
 
         SET @c_SQLJOIN = + ' SELECT OH.Loadkey,@c_AllExtOrderkey , '
                          + ' @c_Col03, ' + CHAR(13) --3
                          + ' @c_col04, '
                          + ' @c_Col05, ' + CHAR(13) --5
                          + ' @c_Col06, ' + CHAR(13) --6
                          + ' @c_Col07 ,@c_Col08 , PD.CartonNo ,@c_col10 , ' + CHAR(13) --10   
                          + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'  + CHAR(13) --20         
                          + ' '''' ,'''' ,'''' ,'''', ' + CHAR(13) --24
                          + ' '''' ,'''' ,'''' ,'''' ,'''', ' + CHAR(13) --29
                          + ' '''', '
                          + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'  + CHAR(13) --40
                          + ' '''' ,'''' ,PD.LabelNo ,@c_col44 ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' , ' + CHAR(13) --50         
                          + ' '''' ,'''' ,'''' ,'''' ,'''' ,'''' ,'''' ,PIF.Cartontype , '''',PH.Pickslipno '  --60         
                          + CHAR(13) +              
                          + ' FROM PACKHEADER PH WITH (NOLOCK)'        + CHAR(13)  
                          + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno'   + CHAR(13)
                          +   @c_JoinStatement  
                          + ' LEFT JOIN STORER ST WITH (NOLOCK) ON ST.STORERKEY = OH.Consigneekey ' + CHAR(13)
                          + ' LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.Pickslipno = PD.Pickslipno AND PIF.cartonno = PD.cartonno ' + CHAR(13) 
                          + ' WHERE PH.Pickslipno = @c_Sparm01 '   + CHAR(13)    
                          + ' AND PD.CartonNo = CAST(@c_Sparm02 AS INT)  ' + CHAR(13)  
                          + ' GROUP BY OH.Loadkey, ' +
                          + ' PD.LabelNo ,PD.CartonNo , PH.Pickslipno, PIF.Cartontype ' + CHAR(13)  
                          + @c_Sorting   
     
            
      IF @b_debug=1         
      BEGIN          
         PRINT @c_SQLJOIN            
      END                  
                
      SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
                +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
                +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
                +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +             
                +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +             
                +',Col55,Col56,Col57,Col58,Col59,Col60) '    
                  

         SET @c_SQL = @c_SQL + @c_SQLJOIN  
       
      
              
                
  
      SET @c_ExecArguments =    N'  @c_Sparm01         NVARCHAR(80) '      
                               + ', @c_Sparm02         NVARCHAR(80) '       
                               + ', @c_Sparm03         NVARCHAR(80) '  
                               + ', @c_AllExtOrderkey  NVARCHAR(80) '   
                               + ', @c_Col10           NVARCHAR(80) '   
                               + ', @c_Col04           NVARCHAR(80) '   
                               + ', @c_Col03           NVARCHAR(80) '    
                               + ', @c_Col05           NVARCHAR(80) '  
                               + ', @c_Col06           NVARCHAR(80) '   
                               + ', @c_Col07           NVARCHAR(80) '  
                               + ', @c_Col08           NVARCHAR(80) ' 
                               + ', @c_Col44           NVARCHAR(80) '

  
                           
                           
      EXEC sp_ExecuteSql     @c_SQL       
                           , @c_ExecArguments      
                           , @c_Sparm01      
                           , @c_Sparm02    
                           , @c_Sparm03  
                           , @c_AllExtOrderkey   
                           , @c_Col10            
                           , @c_Col04            
                           , @c_Col03            
                           , @c_Col05           
                           , @c_Col06           
                           , @c_Col07            
                           , @c_Col08           
                           , @c_Col44 
          
      IF @b_debug=1          
      BEGIN            
         PRINT @c_SQL            
      END             
        
      --SELECT * FROM #RESULT  
      --GOTO EXIT_SP  

       SELECT @n_TTLPADQTY = SUM(PAD.qty)
             ,@n_TTLCTN = MAX(PAD.CartonNo)
       FROM PACKDETAIL PAD WITH (NOLOCK)
       WHERE PAD.pickslipno = @c_Sparm01
       AND   PAD.CartonNo = CAST(@c_Sparm02 AS INT) 

      SELECT @n_TTLCTN = MAX(PAD.CartonNo)
       FROM PACKDETAIL PAD WITH (NOLOCK)
       WHERE PAD.pickslipno = @c_Sparm01

      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT col43,col60,CAST(col09 AS INT)      
      FROM #Result   
      WHERE Col60 = @c_Sparm01
      ORDER BY col60, CAST(col09 AS INT)  ,col43
  
      OPEN CUR_RowNoLoop     
        
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_LabelNo, @c_Pickslipno, @c_CartonNo   
  
      WHILE @@FETCH_STATUS <> -1   
      BEGIN  
         INSERT INTO #Temp_Packdetail  
         SELECT @c_Pickslipno,Convert(nvarchar(8), lott.lottable04, 112) , @c_CartonNo, PID.CaseID , PD.SKU,S.DESCR, PID.loc, SUM(PID.Qty), 'N'  
         FROM PACKHEADER PH WITH (NOLOCK)  
         JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.PickSlipNo = PD.Pickslipno   
         JOIN PICKDETAIL PID WITH (NOLOCK) ON PID.CaseID = PD.LabelNo AND PID.Sku = PD.SKU     
         JOIN SKU S WITH (NOLOCK) ON S.Sku = PD.SKU AND S.storerkey = PD.Storerkey    
         JOIN dbo.LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.lot = PID.lot AND LotT.sku = PID.sku 
         WHERE PD.PickSlipNo = @c_Pickslipno     
         AND PD.CartonNo = CAST(@c_CartonNo AS INT)  
         AND PD.LabelNo = @c_LabelNo  
         GROUP BY PID.CaseID, PD.SKU, PID.loc , s.DESCR ,Convert(nvarchar(8), lott.lottable04, 112)
         ORDER BY PID.loc
  
         SET @c_SKU01  = ''  
         SET @c_loc01 = ''  
         SET @c_Qty01  = ''  
         SET @c_SKU02  = ''  
         SET @c_loc02 = ''  
         SET @c_Qty02  = ''  
         SET @c_SKU03  = ''  
         SET @c_loc03 = ''  
         SET @c_Qty03  = ''  
         SET @c_SKU04  = ''  
         SET @c_loc04 = ''  
         SET @c_Qty04  = '' 
         SET @c_SKU05  = ''  
         SET @c_loc05 = ''  
         SET @c_Qty05  = ''   
         SET @c_SKU06  = ''  
         SET @c_loc06 = ''  
         SET @c_Qty06  = ''  
         SET @c_SKU07  = ''  
         SET @c_loc07 = ''  
         SET @c_Qty07  = ''  
         SET @c_SKU08  = ''  
         SET @c_loc08 = ''  
         SET @c_Qty08  = ''  
         SET @c_SKU09  = ''  
         SET @c_loc09 = ''  
         SET @c_Qty09  = ''  
         SET @c_SKU10  = ''  
         SET @c_loc10 = ''  
         SET @c_Qty10  = '' 
         SET @c_ExpDate01  = ''     
         SET @c_ExpDate02  = '' 
         SET @c_ExpDate03  = '' 
         SET @c_ExpDate04  = '' 
         SET @c_ExpDate05  = '' 
         SET @c_ExpDate06  = '' 
         SET @c_ExpDate07  = '' 
         SET @c_ExpDate08  = '' 
         SET @c_ExpDate09  = '' 
         SET @c_ExpDate10  = '' 
 

         IF @b_debug = 1  
            SELECT * FROM #Temp_Packdetail  
  
         SELECT @n_CntRec = COUNT (1)    
         FROM #Temp_Packdetail  
         WHERE Pickslipno = @c_Pickslipno  
         --AND LabelNo = @c_LabelNo  
         AND CartonNo = @c_CartonNo  
         AND Retreive = 'N'  
  
         SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END     
        
         WHILE @n_intFlag <= @n_CntRec               
         BEGIN  
            IF @n_intFlag > @n_MaxLine AND (@n_intFlag % @n_MaxLine) = 1  
            BEGIN   
               SET @n_CurrentPage = @n_CurrentPage + 1  
  
               IF (@n_CurrentPage > @n_TTLpage)     
               BEGIN    
                  BREAK;    
               END  
              
               INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                     
              ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                   
              ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                    
              ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                     
              ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                   
              ,Col55,Col56,Col57,Col58,Col59,Col60)     
               SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10,         
                           '','','','','', '','','','','',  
                           '','','','','','','','','','',                  
                           '','','','','', '','','','','',                       
                           '','',Col43,Col44,'', '','','','','',                   
                           '','','','','', '','',Col58,'',Col60   
               FROM #Result WHERE col60 <> ''  
  
               SET @c_SKU01  = ''  
               SET @c_loc01 = ''  
               SET @c_Qty01  = ''  
               SET @c_SKU02  = ''  
               SET @c_loc02 = ''  
               SET @c_Qty02  = ''  
               SET @c_SKU03  = ''  
               SET @c_loc03 = ''  
               SET @c_Qty03  = ''  
               SET @c_SKU04  = ''  
               SET @c_loc04 = ''  
               SET @c_Qty04  = ''  
               SET @c_SKU05  = ''  
               SET @c_loc05 = ''  
               SET @c_Qty05  = ''  
               SET @c_SKU06  = ''  
               SET @c_loc06 = ''  
               SET @c_Qty06  = ''  
               SET @c_SKU07  = ''  
               SET @c_loc07 = ''  
               SET @c_Qty07  = ''  
               SET @c_SKU08  = ''  
               SET @c_loc08 = ''  
               SET @c_Qty08  = ''  
               SET @c_SKU09  = ''  
               SET @c_loc09 = ''  
               SET @c_Qty09  = ''  
               SET @c_SKU10  = ''  
               SET @c_loc10 = ''  
               SET @c_Qty10  = '' 

               SET @c_ExpDate01  = ''     
               SET @c_ExpDate02  = '' 
               SET @c_ExpDate03  = '' 
               SET @c_ExpDate04  = '' 
               SET @c_ExpDate05  = '' 
               SET @c_ExpDate06  = '' 
               SET @c_ExpDate07  = '' 
               SET @c_ExpDate08  = '' 
               SET @c_ExpDate09  = '' 
               SET @c_ExpDate10  = ''  

            END  
  
            SELECT   @c_SKU      = SDESCR      
                   , @c_loc      = loc     
                   , @c_Qty      = Qty 
                   , @c_ExpDate  = ExpDate 
            FROM #Temp_Packdetail   
            WHERE ID = @n_intFlag  
  
            IF (@n_intFlag % @n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage    
            BEGIN   
               SET @c_SKU01      = @c_SKU         
               SET @c_loc01      = @c_loc       
               SET @c_Qty01      = @c_Qty  
               SET @c_ExpDate01  = @c_ExpDate
            END     
            ELSE IF (@n_intFlag % @n_MaxLine) = 2 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU02      = @c_SKU         
               SET @c_loc02      = @c_loc       
               SET @c_Qty02      = @c_Qty         
               SET @c_ExpDate02  = @c_ExpDate    
            END    
            ELSE IF (@n_intFlag % @n_MaxLine) = 3 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU03      = @c_SKU         
               SET @c_loc03      = @c_loc       
               SET @c_Qty03      = @c_Qty 
               SET @c_ExpDate03 = @c_ExpDate        
            END   
            ELSE IF (@n_intFlag % @n_MaxLine) = 4 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU04      = @c_SKU         
               SET @c_loc04      = @c_loc       
               SET @c_Qty04      = @c_Qty 
               SET @c_ExpDate04  = @c_ExpDate        
            END   
            ELSE IF (@n_intFlag % @n_MaxLine) = 5 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU05      = @c_SKU         
               SET @c_loc05      = @c_loc       
               SET @c_Qty05      = @c_Qty   
               SET @c_ExpDate05  = @c_ExpDate       
            END 
            ELSE IF (@n_intFlag % @n_MaxLine) = 6 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU06      = @c_SKU         
               SET @c_loc06      = @c_loc       
               SET @c_Qty06      = @c_Qty   
               SET @c_ExpDate06 = @c_ExpDate        
            END 
            ELSE IF (@n_intFlag % @n_MaxLine) = 7 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU07       = @c_SKU         
               SET @c_loc07       = @c_loc       
               SET @c_Qty07       = @c_Qty  
               SET @c_ExpDate07   = @c_ExpDate         
            END 
            ELSE IF (@n_intFlag % @n_MaxLine) = 8 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU08      = @c_SKU         
               SET @c_loc08      = @c_loc       
               SET @c_Qty08      = @c_Qty   
               SET @c_ExpDate08  = @c_ExpDate         
            END 
            ELSE IF (@n_intFlag % @n_MaxLine) = 9 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU09      = @c_SKU         
               SET @c_loc09      = @c_loc       
               SET @c_Qty09      = @c_Qty  
               SET @c_ExpDate09  = @c_ExpDate          
            END 
            ELSE IF (@n_intFlag % @n_MaxLine) = 0 --AND @n_recgrp = @n_CurrentPage    
            BEGIN     
               SET @c_SKU10      = @c_SKU         
               SET @c_loc10      = @c_loc       
               SET @c_Qty10      = @c_Qty   
               SET @c_ExpDate10  = @c_ExpDate        
            END       
            
            UPDATE #Result  
            SET   Col11 = @c_SKU01      
                , Col14 = @c_SKU02      
                , Col17 = @c_SKU03         
                , Col20 = @c_SKU04         
                , Col23 = @c_SKU05     
                , Col12 = @c_loc01  
                , Col15 = @c_loc02   
                , Col18 = @c_loc03         
                , Col21 = @c_loc04       
                , Col24 = @c_loc05      
                , Col13 = @c_Qty01      
                , Col16 = @c_Qty02       
                , Col19 = @c_Qty03         
                , Col22 = @c_Qty04         
                , Col25 = @c_Qty05     
                , Col41 = @n_TTLPADQTY
                , Col42 = CAST(@n_CurrentPage AS NVARCHAR(5)) + '/' + CAST(@n_TTLpage AS NVARCHAR(5))
                , Col26 = @c_SKU06
                , Col29 = @c_SKU07
                , Col32 = @c_SKU08
                , Col35 = @c_SKU09
                , Col38 = @c_SKU10  
                , Col27 = @c_loc06
                , Col30 = @c_loc07
                , Col33 = @c_loc08
                , Col36 = @c_loc09
                , Col39 = @c_loc10
                , Col28 = @c_Qty06
                , Col31 = @c_Qty07
                , Col34 = @c_Qty08
                , Col37 = @c_Qty09
                , Col40 = @c_Qty10
                , Col45 = @c_ExpDate01 
                , Col46 = @c_ExpDate02 
                , Col47 = @c_ExpDate03 
                , Col48 = @c_ExpDate04 
                , Col49 = @c_ExpDate05 
                , Col50 = @c_ExpDate06 
                , Col51 = @c_ExpDate07
                , Col52 = @c_ExpDate08
                , Col53 = @c_ExpDate09
                , Col54 = @c_ExpDate10
                , Col59 = @n_TTLCTN
            WHERE ID = @n_CurrentPage AND Col60 <> ''  
  
            UPDATE #Temp_Packdetail  
            SET Retreive = 'Y'  
            WHERE ID = @n_intFlag  
  
            SET @n_intFlag = @n_intFlag + 1  
           
            IF @n_intFlag > @n_CntRec    
            BEGIN    
               BREAK;    
            END    
         END  
  
         --SELECT @n_SumQty = SUM(PD.Qty)  
         --FROM PACKDETAIL PD (NOLOCK)  
         --WHERE PD.PickSlipNo = @c_Pickslipno  
         --AND PD.LabelNo = @c_LabelNo  
         --AND PD.CartonNo = @c_CartonNo  
  
         --UPDATE #Result  
         --SET Col25 = @n_SumQty  
         --WHERE Col59 = @c_Pickslipno  
         --AND Col22 = @c_LabelNo  
         --AND Col23 = @c_CartonNo  
  
         FETCH NEXT FROM CUR_RowNoLoop INTO @c_LabelNo, @c_Pickslipno, @c_CartonNo   
   END  
   CLOSE CUR_RowNoLoop  
   DEALLOCATE CUR_RowNoLoop  
  
RESULT:  
   SELECT * FROM #Result (nolock)       
   ORDER BY ID     
              
EXIT_SP:      
    
      SET @d_Trace_EndTime = GETDATE()    
      SET @c_UserName = SUSER_SNAME()    
        
   --EXEC isp_InsertTraceInfo     
   --   @c_TraceCode = 'BARTENDER',    
   --   @c_TraceName = 'isp_BT_Bartender_CN_SHIPUCCLBL_SKE_TJ',    
   --   @c_starttime = @d_Trace_StartTime,    
   --   @c_endtime = @d_Trace_EndTime,    
   --   @c_step1 = @c_UserName,    
   --   @c_step2 = '',    
   --   @c_step3 = '',    
   --   @c_step4 = '',    
   --   @c_step5 = '',    
   --   @c_col1 = @c_Sparm01,     
   --   @c_col2 = @c_Sparm02,    
   --   @c_col3 = @c_Sparm03,    
   --   @c_col4 = @c_Sparm04,    
   --   @c_col5 = @c_Sparm05,    
   --   @b_Success = 1,    
   --   @n_Err = 0,    
   --   @c_ErrMsg = ''                
                            
END -- procedure     
  
  


GO