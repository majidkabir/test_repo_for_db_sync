SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_SHIPUCCLBL_02                                    */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2019-05-31 1.0  CSCHONG    Created (WMS-9145)                              */    
/* 2019-12-26 1.1  WLChooi    WMS-11506 - Add Col20 and modify Col01 (WL01)   */
/* 2020-06-11 1.2  WLChooi    Bug Fix - Filter by Pickslipno (WL02)           */
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_SHIPUCCLBL_02]                        
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
      @c_ReceiptKey      NVARCHAR(10),                      
      @c_sku             NVARCHAR(20),                           
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_col58           NVARCHAR(10)        
      
  DECLARE @d_Trace_StartTime   DATETIME,     
          @d_Trace_EndTime    DATETIME,    
          @c_Trace_ModuleName NVARCHAR(20),     
          @d_Trace_Step1      DATETIME,     
          @c_Trace_Step1      NVARCHAR(20),    
          @c_UserName         NVARCHAR(20),  
          @c_PLOC01           NVARCHAR(20),           
          @c_PLOC02           NVARCHAR(20),    
          @c_PLOC03           NVARCHAR(20),           
          @c_PLOC04           NVARCHAR(20),  
          @c_SKU01            NVARCHAR(20),           
          @c_SKU02            NVARCHAR(20),    
          @c_SKU03            NVARCHAR(20),           
          @c_SKU04            NVARCHAR(20),              
          @c_SKUQty01         NVARCHAR(10),          
          @c_SKUQty02         NVARCHAR(10),    
          @c_SKUQty03         NVARCHAR(10),          
          @c_SKUQty04         NVARCHAR(10),                       
          @n_TTLpage          INT,          
          @n_CurrentPage      INT,  
          @n_MaxLine          INT  ,  
          @n_MaxCtnNo          INT  ,  
          @c_labelno          NVARCHAR(20) ,  
          @c_pickslipno       NVARCHAR(20) ,  
          @c_orderkey         NVARCHAR(20) ,  
          @n_skuqty           INT ,  
          @n_skurqty          INT ,  
          @c_PLOC             NVARCHAR(20),   
          @c_cartonno         NVARCHAR(5),  
          @n_loopno           INT,  
          @c_LastRec          NVARCHAR(1),  
          @c_LastCtn          NVARCHAR(1),  
          @c_ExecStatements   NVARCHAR(4000),      
          @c_ExecArguments    NVARCHAR(4000) ,  
          @n_ConsigneeKey     NVARCHAR(10),  
          @n_Col03            NVARCHAR(80),  
          @n_Col04            NVARCHAR(80),  
          @n_Col05            NVARCHAR(80),  
          @n_Col06            NVARCHAR(80),  
          @n_Col07            NVARCHAR(80),
          @dt_DeliveryDate    DATETIME   --WL01  
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0    
    SET @c_SQL = ''       
    SET @n_CurrentPage = 1  
    SET @n_TTLpage =1       
    SET @n_MaxLine = 3--4      
    SET @n_CntRec = 1    
    SET @n_intFlag = 1   
    SET @n_loopno = 1        
    SET @c_LastRec = 'Y'  
    SET @n_ConsigneeKey = ''  
    SET @n_Col03 = ''  
    SET @n_Col04 = ''  
    SET @n_Col05 = ''  
    SET @n_Col06 = ''  
    SET @n_Col07 = ''  
                
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
       
       
      CREATE TABLE [#TEMPPDSKULOC] (                     
      [ID]           [INT] IDENTITY(1,1) NOT NULL,                                        
      [Pickslipno]   [NVARCHAR] (20) NULL,    
      [cartonno]     INT NULL,         
      [SKU]          [NVARCHAR] (20) NULL,             
      [PQty]         INT,  
      [labelno]      [NVARCHAR](20) NULL,  
   --[PLOC]         [NVARCHAR](20) NULL,   
      [Retrieve]     [NVARCHAR](1) default 'N')  
      --RecGrp        INT)       
  
   --WL01 Start
   /*SELECT TOP  1  @n_ConsigneeKey  =  o.ConsigneeKey   
   FROM dbo.ORDERS  o WITH (NOLOCK)   
   JOIN dbo.PACKHEADER pah  WITH  (NOLOCK) ON o.LoadKey = pah.LoadKey  
   WHERE pah.PickSlipNo  = @c_Sparm01  */

   SELECT TOP  1  @n_ConsigneeKey  =  o.ConsigneeKey
                , @dt_DeliveryDate =  o.DeliveryDate
   FROM dbo.PACKHEADER pah  WITH  (NOLOCK)
   JOIN dbo.LOADPLANDETAIL lpd WITH (NOLOCK) ON lpd.Loadkey = pah.Loadkey
   JOIN dbo.ORDERS  o WITH (NOLOCK) ON o.Orderkey = lpd.orderkey  
   WHERE pah.PickSlipNo  = @c_Sparm01  
   --WL01 End
        
   SELECT @n_Col03 = Notes2,  
          @n_Col04 = Notes1,  
          @n_Col05 = SUSR2,  
          @n_Col06 = SUSR1,  
          @n_Col07 = SUBSTRING(StorerKey,4,LEN(StorerKey)-3)  
   FROM dbo.STORER WHERE StorerKey = @n_ConsigneeKey  
           
           
         SET @c_SQLJOIN = +' SELECT TOP 1 O.Externorderkey,CONVERT(NVARCHAR(5), pad.cartonno),'  --WL01
             + ' '''','''','''','+ CHAR(13)      --5        
             + ' '''','''','''','''','''','      
             --+ ' Substring(RTRIM(ISNULL(ST.notes2,'''')),1,80),Substring(RTRIM(ISNULL(ST.notes1,'''')),1,80),RTRIM(ISNULL(ST.SUSR2,'''')),'+ CHAR(13)      --5        
             --+ ' RTRIM(ISNULL(ST.SUSR1,'''')),o.consigneekey,'''','''','''','   
             + ' '''','''','''','''','''','     --15    
             + ' '''','''','''','''','''','     --20         
             + CHAR(13) +        
             + ' '''','''','''','''','''','''','''','''','''','''','  --30     
             + ' '''','''','''','''','''','''','''','''','''','''','   --40         
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50         
             + ' '''','''','''','''','''','''', CONVERT(NVARCHAR(80), GETDATE(), 120) ,pad.labelno,pad.pickslipno,''O'' '   --60            
             + CHAR(13) +                   
             --+ ' FROM ORDERS o WITH (NOLOCK) '         
             --+ ' JOIN OrderDetail od WITH (NOLOCK) ON o.OrderKey=od.OrderKey '     
             --+ ' JOIN PickDetail pid WITH (NOLOCK) ON od.OrderKey=pid.OrderKey AND od.OrderLineNumber=pid.OrderLineNumber '   
             --+ ' JOIN PackDetail  Pd WITH (NOLOCK) ON right(pd.LabelNo,18)=pid.DropID '     
             --+ ' JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=o.consigneekey '       
             + ' FROM LoadPlan lp WITH (NOLOCK) '  
             + ' JOIN PackHeader pah WITH (NOLOCK) ON lp.LoadKey =  pah.LoadKey '  
             + ' JOIN PackDetail pad WITH (NOLOCK) ON pah.PickSlipNo = pad.PickSlipNo '     
             + ' JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.Loadkey = lp.Loadkey ' --WL01    
             + ' JOIN Orders o WITH (NOLOCK) ON o.Orderkey = lpd.Orderkey '          --WL01     
             + ' WHERE pad.pickslipno = @c_Sparm01 '     
             + ' AND pad.Cartonno >= CONVERT(INT,@c_Sparm02) '                      
             + ' AND pad.Cartonno <= CONVERT(INT,@c_Sparm03) '      
           
       
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
  
  
 SET @c_ExecArguments = N'  @c_Sparm01          NVARCHAR(80)'      
                       + ', @c_Sparm02          NVARCHAR(80) '   
                       + ', @c_Sparm03          NVARCHAR(80) '       
                           
                           
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
     
        
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (nolock)          
   END          
    
    
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT col58,col59,col02       
   FROM #Result                 
   WHERE Col60 = 'O'           
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_pickslipno,@c_cartonno      
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
      IF @b_debug='1'                
      BEGIN                
         PRINT @c_labelno                   
      END   
        
      INSERT INTO #TEMPPDSKULOC (pickslipno,Cartonno,SKU,PQty,labelno,Retrieve)          
      SELECT DISTINCT @c_pickslipno,CAST(@c_cartonno as INT),PD.sku, SUM(pd.qty),@c_labelno,'N'  
      FROM  PackDetail AS pd WITH (NOLOCK)   
      WHERE pd.LabelNo = @c_labelno  
      AND pd.Pickslipno = @c_pickslipno   --WL02
     -- AND pd.cartonno = CONVERT(INT,@c_cartonno)  
      --AND o.orderkey = @c_orderkey  
      GROUP BY PD.sku  
        
      SET @c_SKU01 = ''  
      SET @c_SKU02 = ''  
      SET @c_SKU03 = ''  
      --SET @c_SKU04 = ''  
      --SET @c_PLOC01 = ''  
      --SET @c_PLOC02 = ''  
      --SET @c_PLOC03 = ''  
      --SET @c_PLOC04 = ''  
      SET @c_SKUQty01 = ''  
      SET @c_SKUQty02 = ''  
      SET @c_SKUQty03 = ''  
      --SET @c_SKUQty04 = ''  
  
      SET @n_MaxCtnNo =1  
      SET @c_LastCtn = 'N'  
      --SELECT * FROM #TEMPLLISKUPHL03  
  
      SELECT @n_CntRec = COUNT (1)  
      FROM #TEMPPDSKULOC   
      WHERE labelno = @c_labelno  
      AND pickslipno = @c_pickslipno   
      AND Retrieve = 'N'   
  
      SELECT @n_MaxCtnNo = MAX(Cartonno)  
      FROM PackDetail WITH (NOLOCK)  
      WHERE PickSlipNo = @c_pickslipno  
  
      IF CAST(@c_cartonno as int) = @n_MaxCtnNo  
      BEGIN  
        SET @c_LastCtn = 'Y'  
      END  
  
      IF @c_LastCtn = 'Y'  
      BEGIN  
      
         UPDATE #Result                    
         SET Col02 =  CONVERT(NVARCHAR(5),@n_MaxCtnNo) + '-' + @c_cartonno  
         WHERE ID = @n_CurrentPage   
      END  
        
      SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END   
        
      --SELECT * FROM #TEMPEATSKU01  
        
     WHILE @n_intFlag <= @n_CntRec             
     BEGIN    
         
       IF @n_intFlag > @n_MaxLine AND (@n_intFlag%@n_MaxLine) = 1 --AND @c_LastRec = 'N'  
       BEGIN  
           
         SET @n_CurrentPage = @n_CurrentPage + 1  
           
       IF (@n_CurrentPage>@n_TTLpage)   
       BEGIN  
         BREAK;  
       END    
      
         INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                               ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                               ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                               ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                               ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                               ,Col55,Col56,Col57,Col58,Col59,Col60)   
         SELECT TOP 1 Col01,Col02,'','','','','','','','',                   
                      '','','','','', '','','','','',                
                      '','','','','', '','','','','',                
                      '','','','','', '','','','','',                   
                      '','','','','', '','','','','',                 
                      '','','','','', '',col57,col58,col59,col60  
          FROM  #Result   
          WHERE Col60='O'   
            
       
         
               SET @c_SKU01 = ''  
               SET @c_SKU02 = ''  
               SET @c_SKU03 = ''  
               --SET @c_SKU04 = ''  
               --SET @c_PLOC01 = ''  
               --SET @c_PLOC02 = ''  
               --SET @c_PLOC03 = ''  
               --SET @c_PLOC04 = ''  
               SET @c_SKUQty01 = ''  
               SET @c_SKUQty02 = ''  
               SET @c_SKUQty03 = ''  
              -- SET @c_SKUQty04 = ''                   
        
       END      
              
        
      SELECT @c_sku = SKU,  
          --@c_PLOC = PLOC,  
             @n_skuqty = SUM(PQty)  
      FROM #TEMPPDSKULOC   
      WHERE ID = @n_intFlag  
      GROUP BY SKU--,PLOC  
        
    
      IF (@n_intFlag%@n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage  
       BEGIN   
         --SELECT '1'         
        SET @c_sku01    = @c_sku  
  --SET @c_PLOC01  = @c_PLOC  
        SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)        
       END          
         
       ELSE IF (@n_intFlag%@n_MaxLine) = 2  --AND @n_recgrp = @n_CurrentPage  
       BEGIN      
         --SELECT '2'       
        SET @c_sku02 = @c_sku  
  --SET @c_PLOC02  = @c_PLOC  
        SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)           
       END    
        ELSE IF (@n_intFlag%@n_MaxLine) = 0--3  --AND @n_recgrp = @n_CurrentPage  
       BEGIN      
         --SELECT '3'       
        SET @c_sku03 = @c_sku  
  --SET @c_PLOC03  = @c_PLOC  
        SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)           
       END     
       -- ELSE IF (@n_intFlag%@n_MaxLine) = 0  --AND @n_recgrp = @n_CurrentPage  
       --BEGIN      
         --SELECT '4'       
        --SET @c_sku04= @c_sku  
  --SET @c_PLOC04  = @c_PLOC  
        --SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)           
       --END              
            
        UPDATE #Result                    
        SET Col03 = @n_Col03,  
            Col04 = @n_Col04,  
            Col05 = @n_Col05,  
            Col06 = @n_Col06,  
            Col07 = @n_Col07,  
          --Col08 = @c_PLOC01,    
            Col09 = @c_sku01,   
            Col10 = @c_SKUQty01,          
          --Col11 = @c_PLOC02,          
            Col12 = @c_sku02,                  
            Col13 = @c_SKUQty02,   
          --Col14 = @c_PLOC03,          
            Col15 = @c_sku03,           
            Col16 = @c_SKUQty03,  
          --Col17 = @c_PLOC04,         
          --Col18 = @c_sku04,          
          --Col19 = @c_SKUQty04   
            Col20 = CONVERT(NVARCHAR(80),@dt_DeliveryDate,101)   --WL01      
        WHERE ID = @n_CurrentPage   
            
         -- SELECT * FROM #Result    
           
         UPDATE  #TEMPPDSKULOC  
         SET Retrieve ='Y'  
         WHERE ID= @n_intFlag   
                      
          
     SET @n_intFlag = @n_intFlag + 1    
  
     IF @n_intFlag > @n_CntRec  
     BEGIN  
       BREAK;  
     END        
   END  
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_labelno,@c_orderkey,@c_cartonno          
          
      END -- While                     
      CLOSE CUR_RowNoLoop                    
      DEALLOCATE CUR_RowNoLoop     
     
         
   SELECT * FROM #Result (nolock)      
   --WHERE ISNULL(Col02,'') <> ''      
   ORDER BY col58  
              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   EXEC isp_InsertTraceInfo     
      @c_TraceCode = 'BARTENDER',    
      @c_TraceName = 'isp_BT_Bartender_SHIPUCCLBL_02',    
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
     
    
                                    
END -- procedure     
  
  


GO