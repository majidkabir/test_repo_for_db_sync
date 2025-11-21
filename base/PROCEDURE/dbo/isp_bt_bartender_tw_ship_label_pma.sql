SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_TW_Ship_Label_PMA                                */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2017-08-23 1.0  CSCHONG    Created (WMS-2526)                              */ 
/* 2018-07-20 1.1  CSCHONG    WMS-5595 - add new field (CS01)                 */
/* 2018-12-06 1.2  CSCHONG    WMS-7169 - revised field logic (CS02)           */
/* 2019-05-21 1.3  CSCHONG    WMS-9097 - Add new field (CS03)                 */
/* 2021-03-03 1.4  WLChooi    WMS-16602 - Add logic to get Col01 (WL01)       */
/* 2023-08-17 1.5  WLChooi    WMS-23402 - Added Col60 (WL02)                  */
/* 2023-08-17 1.5  WLChooi    DevOps Combine Script                           */
/******************************************************************************/                
                  
CREATE   PROC [dbo].[isp_BT_Bartender_TW_Ship_Label_PMA]                      
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
      @c_ExternOrderkey  NVARCHAR(10),                    
     -- @c_Sku             NVARCHAR(20),                         
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
      @n_MaxLine         INT,
      @n_CurrentPage     INT,                              
      @n_RecCnt          INT,
      @n_TTLpage         INT                       
          
    
   DECLARE @d_Trace_StartTime  DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_getPickslipno    NVARCHAR(10),                        
           @c_getlabelno       NVARCHAR(20),
           @c_getcartonno      NVARCHAR(30)      
           
   DECLARE @c_ExecStatements       NVARCHAR(MAX)  
         , @c_ExecArguments        NVARCHAR(MAX)  
         , @c_ExecStatements2      NVARCHAR(MAX)  
         , @c_ExecStatementsAll    NVARCHAR(MAX)    
         , @n_continue             INT  
         
   DECLARE    
      @c_line01            NVARCHAR(80), 
      @c_StyleC            NVARCHAR(80),     
      @c_SSize             NVARCHAR(80),    
      @n_qty               INT,            
      @c_StyleC01          NVARCHAR(80),  
      @c_SSize01           NVARCHAR(80),  
      @n_qty01             INT,         
      @c_line02            NVARCHAR(80), 
      @c_StyleC02          NVARCHAR(80),
      @c_SSize02           NVARCHAR(80),
      @n_qty02             INT,            
      @c_line03            NVARCHAR(80), 
      @c_StyleC03          NVARCHAR(80), 
      @c_SSize03           NVARCHAR(80), 
      @n_qty03             INT,         
      @c_line04            NVARCHAR(80), 
      @c_StyleC04          NVARCHAR(80), 
      @c_SSize04           NVARCHAR(80), 
      @n_qty04             INT,          
      @c_line05            NVARCHAR(80),  
      @c_StyleC05          NVARCHAR(80),
      @n_qty05             INT,  
      @c_SSize05           NVARCHAR(80),        
      @c_line06            NVARCHAR(80),
      @c_StyleC06          NVARCHAR(80), 
      @c_SSize06           NVARCHAR(80),
      @n_qty06             INT,         
      @c_line07            NVARCHAR(80),    
      @c_StyleC07          NVARCHAR(80),  
      @c_SSize07           NVARCHAR(80),   
      @n_qty07             INT,   
      @c_line08            NVARCHAR(80),
      @c_StyleC08          NVARCHAR(80),  
      @c_SSize08           NVARCHAR(80), 
      @n_qty08             INT,          
      @c_line09            NVARCHAR(80),  
      @c_StyleC09          NVARCHAR(80), 
      @c_SSize09           NVARCHAR(80), 
      @n_qty09             INT,        
      @c_line10            NVARCHAR(80),
      @c_StyleC10          NVARCHAR(80),
      @c_SSize10           NVARCHAR(80),
      @n_qty10             INT,
      @c_Col01             NVARCHAR(100) = '',    --WL01  
      @c_GetStorerkey      NVARCHAR(15)  = '',    --WL01       
      @c_Col06             NVARCHAR(100) = ''     --WL01        
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
   -- SET RowNo = 0             
   SET @c_SQL = ''  
   SET @c_skugroup = ''    
   SET @n_totalcase = 0  
   SET @n_sequence  = 1 
   SET @n_CntSku = 1  
   SET @n_TTLQty = 0           
   SET @n_CurrentPage = 1               
   SET @n_intFlag = 1                 
   SET @n_RecCnt = 1                
    
   --WHILE @@TRANCOUNT > 0
   --BEGIN
   --   COMMIT TRAN
   --END   
              
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

   CREATE TABLE [#CTNSKUContent] (                     
      [ID]                    [INT] IDENTITY(1,1) NOT NULL,
      [Pickslipno]            [NVARCHAR] (20)  NULL,
      cartonno                [NVARCHAR] (10) NULL,  
      [StyleC]                [NVARCHAR] (80) NULL,                                    
      [SSize]                 [NVARCHAR] (80) NULL,                                              
      [skuqty]                INT NULL,                             
      [Retrieve]              [NVARCHAR] (1) default 'N')                 
          
   --WL01 S
   SELECT @c_GetStorerkey = Storerkey
   FROM PACKHEADER (NOLOCK)
   WHERE PickSlipNo = @c_Sparm01
   
   SELECT @c_Col01 = ISNULL(CODELKUP.Notes, 'ISNULL(SSOD.Route,'''')')
   FROM CODELKUP (NOLOCK) 
   WHERE LISTNAME = 'REPORTCFG' 
   AND Code = 'GetCol01' 
   AND Long = 'isp_BT_Bartender_TW_Ship_Label_PMA' 
   AND Short = 'Y' 
   AND Storerkey = @c_GetStorerkey

   IF ISNULL(@c_Col01,'') = ''
   BEGIN 
      SET @c_Col01 = N'ISNULL(SSOD.Route,'''')'
   END

   SELECT @c_Col06 = ISNULL(CODELKUP.Notes, 'PD.LabelNo')
   FROM CODELKUP (NOLOCK) 
   WHERE LISTNAME = 'REPORTCFG' 
   AND Code = 'GetCol06' 
   AND Long = 'isp_BT_Bartender_TW_Ship_Label_PMA' 
   AND Short = 'Y' 
   AND Storerkey = @c_GetStorerkey

   IF ISNULL(@c_Col06,'') = ''
   BEGIN 
      SET @c_Col06 = 'PD.LabelNo'
   END
   --WL01 E  
     
   --BEGIN TRAN          
   SET @c_SQLJOIN = +N' SELECT DISTINCT ' + @c_Col01 + ',o.C_Company,'   --WL01
                    + ' (RTRIM(o.C_Address1) + RTRIM(o.C_Address2) + RTRIM(o.C_Address3)+RTRIM(o.C_Address4)),o.ExternOrderKey,o.[notes],'       --5
                    + ' ' + @c_Col06 + ',ph.Pickslipno,CONVERT(NVARCHAR(10),LP.lpuserdefdate01,111),RTRIM(pd.CartonNo),(RTRIM(F.city) + RTRIM(F.Address1)),' --10   --CS02   --WL01             
                    + ' F.phone1 ,o.ConsigneeKey,o.orderkey,'''','''', ' --15                    --(CS02)   --(CS03)
                    + ' '''','''','''','''','''','     --20       
                    --    + CHAR(13) +      
                    + ' '''','''','''','''','''','''','''','''','''','''','  --30  
                    + ' '''','''','''','''','''','''','''','''','''','''','   --40       
                    + ' '''','''','''','''','''','''','''','''','''','''', '  --50       
                    + ' '''','''','''','''',o.Door,o.shipperkey,ph.status,o.storerkey,ph.TTLCNTS,CONVERT(NVARCHAR(10), O.DeliveryDate, 111) '   --60   --CS03   --WL02
                    --  + CHAR(13) +            
                    + ' FROM PackHeader AS ph WITH (NOLOCK)'       
                    + ' JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo'   
                    + ' JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey '    
                    + ' JOIN LOADPLAN LP WITH (NOLOCK) ON LP.loadkey = o.loadkey '
                    + ' JOIN FACILITY F WITH (NOLOCK) ON F.Facility = o.Facility'
                    + ' LEFT JOIN StorerSODefault AS SSOD WITH (NOLOCK) ON SSOD.storerkey=o.consigneekey'   --WL01        
                    + ' WHERE pd.LabelNo =@c_Sparm02'   
                    + ' AND ph.pickslipno =@c_Sparm01 '   
                    + ' GROUP BY ' + @c_Col01 + ',o.C_Company,RTRIM(o.C_Address1),RTRIM(o.C_Address2),RTRIM(o.C_Address3), '   --WL01
                    + ' RTRIM(o.C_Address4),o.ExternOrderKey,o.[notes],' + @c_Col06 + ',ph.Pickslipno,CONVERT(NVARCHAR(10),LP.lpuserdefdate01,111),RTRIM(pd.CartonNo), '  --CS02   --WL01
                    + ' RTRIM(F.city) , RTRIM(F.Address1), F.phone1,o.ConsigneeKey,o.orderkey,o.Door,o.shipperkey,ph.status,o.storerkey,ph.TTLCNTS, '  --CS03    
                    + ' CONVERT(NVARCHAR(10), O.DeliveryDate, 111) '   --WL02
          
   IF @b_debug=1        
   BEGIN        
      SELECT @c_SQLJOIN          
   END                
     PRINT @c_SQLJOIN         
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             +',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
   --SET @c_SQL = @c_SQL + @c_SQLJOIN        

   SET @c_ExecStatements = @c_SQL + CHAR(13) + @c_SQLJOIN 
       
   IF @b_debug=1        
   BEGIN        
      SELECT @c_ExecStatements          
   END  
       
   SET @c_ExecArguments = N' @c_Sparm01     NVARCHAR(60)'  
                          +',@c_Sparm02     NVARCHAR(60)'  

   EXEC sp_ExecuteSql @c_ExecStatements   
                    , @c_ExecArguments  
                    , @c_Sparm01  
                    , @c_Sparm02  
  
     --IF @@ERROR <> 0       
     --BEGIN  
     --  SET @n_continue = 3  
     --  ROLLBACK TRAN  
     --  GOTO EXIT_SP  
     --END 
     --ELSE
     --BEGIN
     --    WHILE @@TRANCOUNT > 0
     --    BEGIN
     --       COMMIT TRAN
     --    END
     -- END

   SET @n_MaxLine    = 10
   --  SET @n_MaxLineRec = 10
   SET @n_TTLpage    = 1 
   SET @c_StyleC     = ''   
   SET @c_SSize      = ''
   SET @n_qty        = 0   

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                   
      SELECT DISTINCT col07,col06,col09       
      FROM #Result 
      WHERE col07 = @c_Sparm01 
      AND col06 = @c_Sparm02               
      ORDER BY col07,col06,col09      
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_getPickslipno,@c_getlabelno,@c_getcartonno
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN 
      INSERT INTO [#CTNSKUContent] (Pickslipno,Cartonno,StyleC,SSize,skuqty,Retrieve)                          
      SELECT ph.PickSlipNo,cast(pd.cartonno as nvarchar(10)),(ISNULL(RTRIM(S.style),'') + ISNULL(RTRIM(S.color),'')),
             ISNULL(RTRIM(S.size),''),sum(pd.Qty),'N'
      FROM PackHeader AS ph WITH (NOLOCK) 
      JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo 
      JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey  
      JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=o.storerkey 
      JOIN SKU S WITH (NOLOCK) ON S.StorerKey=pd.StorerKey AND s.sku = PD.SKU
      WHERE pd.pickslipno =@c_getPickslipno  AND pd.labelno = @c_getlabelno  
      and pd.cartonno = cast(@c_getcartonno as int)
      GROUP BY ph.PickSlipNo,cast(pd.cartonno as nvarchar(10)),(ISNULL(RTRIM(S.style),'') + ISNULL(RTRIM(S.color),'')),
               ISNULL(RTRIM(S.size),'')
      ORDER BY ph.PickSlipNo ,(ISNULL(RTRIM(S.style),'') + ISNULL(RTRIM(S.color),'')),
               ISNULL(RTRIM(S.size),'')   

      SET @c_line01     = ''
      SET @c_StyleC01   = ''
      SET @c_SSize01    = ''
      SET @n_qty01      = 0  
      SET @c_line02     = ''     
      SET @c_StyleC02   = ''
      SET @c_StyleC02   = ''
      SET @c_SSize02    = ''
      SET @n_qty02      = 0          
      SET @c_line03     = ''
      SET @c_StyleC03   = '' 
      SET @c_SSize03    = ''
      SET @n_qty03      = 0       
      SET @c_line04     = ''
      SET @c_StyleC04   = ''
      SET @c_SSize04    = ''
      SET @n_qty04      = 0        
      SET @c_line05     = ''
      SET @c_StyleC05   = ''
      SET @n_qty05      = 0
      SET @c_SSize05    = ''        
      SET @c_line06     = ''
      SET @c_StyleC06   = ''
      SET @c_SSize06    = ''
      SET @n_qty06      = 0       
      SET @c_line07     = ''
      SET @c_StyleC07   = ''
      SET @c_SSize07    = ''
      SET @n_qty07      = 0 
      SET @c_line08     = ''
      SET @c_StyleC08   = ''  
      SET @c_SSize08    = '' 
      SET @n_qty08      = 0        
      SET @c_line09     = ''  
      SET @c_StyleC09   = '' 
      SET @c_SSize09    = '' 
      SET @n_qty09      = 0      
      SET @c_line10     = ''
      SET @c_StyleC10   = ''
      SET @c_SSize10    = ''
      SET @n_qty10      = 0            
      
      SELECT @n_CntRec = COUNT (1)
      FROM [#CTNSKUContent]
      WHERE Pickslipno = @c_getPickslipno
      AND Retrieve = 'N' 
      
      SELECT @n_TTLQty = SUM(skuqty)
      FROM [#CTNSKUContent]
      WHERE Pickslipno = @c_getPickslipno
      --and 

      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine )   

      IF @b_debug = '1'              
      BEGIN              
         SELECT 'carton',* FROM [#CTNSKUContent]    
         select   @n_CntRec '@n_CntRec',  @n_intFlag '@n_intFlag'  
      END 
      
      WHILE @n_intFlag<= @n_CntRec
      BEGIN
         SELECT   @c_StyleC = c.StyleC
                 ,@c_SSize  = c.SSize    
                 ,@n_qty    = c.skuqty  
         FROM  #CTNSKUContent c WITH (NOLOCK) 
         WHERE id = @n_intFlag
            

         IF (@n_intFlag%@n_MaxLine) = 1
         BEGIN
            SET    @c_line01   = '1'
            SET    @c_StyleC01 = @c_StyleC
            SET    @c_SSize01  = @c_SSize
            SET    @n_qty01    = @n_qty        
         END   
         ELSE IF (@n_intFlag%@n_MaxLine) = 2
         BEGIN
            SET     @c_line02   = '2'
            SET     @c_StyleC02 = @c_StyleC
            SET     @c_SSize02  = @c_SSize   
            SET     @n_qty02    = @n_qty          
         END  
         ELSE IF (@n_intFlag%@n_MaxLine) = 3
         BEGIN
            SET    @c_line03   = '3'
            SET    @c_StyleC03 = @c_StyleC
            SET    @c_SSize03  = @c_SSize   
            SET    @n_qty03    = @n_qty          
         END 
         ELSE IF (@n_intFlag%@n_MaxLine) = 4
         BEGIN
            SET    @c_line04    = '4'
            SET    @c_StyleC04  = @c_StyleC
            SET    @c_SSize04   = @c_SSize   
            SET    @n_qty04     = @n_qty          
         END   
         ELSE IF (@n_intFlag%@n_MaxLine) = 5
         BEGIN
            SET    @c_line05   = '5'
            SET    @c_StyleC05 = @c_StyleC
            SET    @c_SSize05  = @c_SSize   
            SET    @n_qty05    = @n_qty          
         END  
         ELSE IF (@n_intFlag%@n_MaxLine) = 6
         BEGIN
            SET    @c_line06   = '6'
            SET    @c_StyleC06 = @c_StyleC
            SET    @c_SSize06  = @c_SSize   
            SET    @n_qty06    = @n_qty          
         END 
         ELSE IF (@n_intFlag%@n_MaxLine) = 7
         BEGIN
            SET    @c_line07   = '7'
            SET    @c_StyleC07 = @c_StyleC
            SET    @c_SSize07  = @c_SSize   
            SET    @n_qty07    = @n_qty          
         END   
         ELSE IF (@n_intFlag%@n_MaxLine) = 8
         BEGIN
            SET    @c_line08   = '8'
            SET    @c_StyleC08 = @c_StyleC
            SET    @c_SSize08  = @c_SSize   
            SET    @n_qty08= @n_qty           
         END  
         ELSE IF (@n_intFlag%@n_MaxLine) = 9
         BEGIN
            SET    @c_line09   = '9'
            SET    @c_StyleC09 = @c_StyleC
            SET    @c_SSize09  = @c_SSize   
            SET    @n_qty09    = @n_qty          
         END     
         ELSE IF (@n_intFlag%@n_MaxLine) = 0
         BEGIN
            SET    @c_line10   = '10'
            SET    @c_StyleC10 = @c_StyleC
            SET    @c_SSize10  = @c_SSize  
            SET    @n_qty10    = @n_qty          
         END  
         
         -- SET @n_TTLQty = (@n_qty01+@n_qty02+@n_qty03+@n_qty04+@n_qty05+@n_qty06+@n_qty07+@n_qty08+@n_qty09+@n_qty10)
         --CS01 start
       
         -- SELECT @n_CurrentPage '@n_CurrentPage',@n_ID '@n_ID'
       
         IF (@n_RecCnt=@n_MaxLine) OR (@n_intFlag = @n_CntRec)     
         BEGIN
         
            UPDATE #Result                    
            SET  
                Col14 = @c_line01,           
                Col15 = @c_StyleC01,          
                Col16 = @c_SSize01,                  
                Col17 =  CASE WHEN @n_qty01 > 0 THEN CONVERT(NVARCHAR(5),@n_qty01) ELSE '' END,           
                Col18 = @c_line02,  
                Col19 = @c_StyleC02,
                Col20 = @c_SSize02,
                Col21 = CASE WHEN @n_qty02 > 0 THEN CONVERT(NVARCHAR(5),@n_qty02) ELSE '' END,
                Col22 = @c_line03,
                col23 = @c_StyleC03,
                Col24 = @c_SSize03,
                Col25 = CASE WHEN @n_qty03 > 0 THEN CONVERT(NVARCHAR(5),@n_qty03) ELSE '' END,
                Col26 = @c_line04,
                col27 = @c_StyleC04,
                Col28 = @c_SSize04,
                Col29 = CASE WHEN @n_qty04 > 0 THEN CONVERT(NVARCHAR(5),@n_qty04) ELSE '' END,
                Col30 = @c_line05,
                col31 = @c_StyleC05,
                Col32 = @c_SSize05,
                col33 = CASE WHEN @n_qty05 > 0 THEN CONVERT(NVARCHAR(5),@n_qty05) ELSE '' END,
                Col34 = @c_line06,
                col35 = @c_StyleC06,
                Col36 = @c_SSize06,
                col37 = CASE WHEN @n_qty06 > 0 THEN CONVERT(NVARCHAR(5),@n_qty06) ELSE '' END,
                Col38 = @c_line07,
                col39 = @c_StyleC07,
                col40 =  @c_SSize07,
                col41 = CASE WHEN @n_qty07 > 0 THEN CONVERT(NVARCHAR(5),@n_qty07) ELSE '' END,
                col42 = @c_line08,
                col43 = @c_StyleC08,
                col44 = @c_SSize08,
                col45 = CASE WHEN @n_qty08 > 0 THEN CONVERT(NVARCHAR(5),@n_qty08) ELSE '' END,
                col46 = @c_line09,
                col47 = @c_StyleC09,
                col48 = @c_SSize09,
                col49 =  CASE WHEN @n_qty09 > 0 THEN CONVERT(NVARCHAR(5),@n_qty09) ELSE '' END,
                col50 = @c_line10,
                col51 = @c_StyleC10,
                col52 = @c_SSize10,
                col53 = CASE WHEN @n_qty10 > 0 THEN CONVERT(NVARCHAR(5),@n_qty10) ELSE '' END,
                col54 = CASE WHEN @n_TTLQty > 0 THEN CONVERT(NVARCHAR(10), @n_TTLQty) ELSE '' END
            WHERE col07 = @c_getPickslipno AND col06 = @c_getlabelno 
            AND id = @n_CurrentPage 
       
            SET @n_RecCnt = 0
         
         END 
 
         --SELECT @n_RecCnt '@n_RecCnt',@n_ID '@n_ID',@n_CntRec '@n_CntRec'
         IF @n_RecCnt = 0 AND (@n_intFlag<@n_CntRec)--(@n_intFlag%@n_MaxLine) = 0 AND (@n_intFlag>@n_MaxLine)
         BEGIN
            SET @n_CurrentPage = @n_CurrentPage + 1   
             
            INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                                ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                                ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                                ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                                ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                                ,Col55,Col56,Col57,Col58,Col59,Col60)             
            SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10,                 
                         Col11,Col12,Col13,'','', '','','','','',              
                         '','','','','', '','','','','',              
                         '','','','','', '','','','','',                 
                         '','','','','', '','','','','',               
                         '','','','',Col55,Col56,Col57,Col58,Col59,Col60   --WL01
            FROM  #Result 
            WHERE col07 = @c_getPickslipno AND col06 = @c_getlabelno                 
         
            SET @c_line01     = ''
            SET @c_StyleC01   = ''
            SET @c_SSize01    = ''
            SET @n_qty01      = 0   
            SET @c_line02     = ''    
            SET @c_StyleC02   = ''
            SET @c_StyleC02   = ''
            SET @c_SSize02    = ''
            SET @n_qty02      = 0          
            SET @c_line03     = ''
            SET @c_StyleC03   = '' 
            SET @c_SSize03    = ''
            SET @n_qty03      = 0       
            SET @c_line04     = ''
            SET @c_StyleC04   = ''
            SET @c_SSize04    = ''
            SET @n_qty04      = 0        
            SET @c_line05     = ''
            SET @c_StyleC05   = ''
            SET @n_qty05      = 0
            SET @c_SSize05    = ''        
            SET @c_line06     = ''
            SET @c_StyleC06   = ''
            SET @c_SSize06    = ''
            SET @n_qty06      = 0       
            SET @c_line07     = ''
            SET @c_StyleC07   = ''
            SET @c_SSize07    = ''
            SET @n_qty07      = 0 
            SET @c_line08     = ''
            SET @c_StyleC08   = ''  
            SET @c_SSize08    = '' 
            SET @n_qty08      = 0        
            SET @c_line09     = ''  
            SET @c_StyleC09   = '' 
            SET @c_SSize09    = '' 
            SET @n_qty09      = 0      
            SET @c_line10     = ''
            SET @c_StyleC10   = ''
            SET @c_SSize10    = ''
            SET @n_qty10      = 0 
             
         END 
               
         SET @n_intFlag = @n_intFlag + 1 
         SET @n_RecCnt = @n_RecCnt + 1
      END      
     
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_getPickslipno,@c_getlabelno,@c_getcartonno                   
            
   END -- While                     
   CLOSE CUR_RowNoLoop                    
   DEALLOCATE CUR_RowNoLoop                
                  
        
--EXEC sp_executesql @c_SQL          
        
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
      @c_TraceName = 'isp_BT_Bartender_TW_Ship_Label_PMA',  
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