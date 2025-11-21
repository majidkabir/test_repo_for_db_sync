SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_KR_shipLabel_CJKE                                */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2017-11-20 1.0  CSCHONG    Created (WMS-3415)                              */ 
/* 2018-02-12 1.1  CSCHONG    WMS-4045 add new field (CS01)                   */
/* 2018-04-20 1.2  CSCHONG    Rmove ANSI_WARNINGS OFF  (CS02)                 */
/* 2019-12-24 1.3  WLChooi    WMS-11485 - Add new field (WL01)                */
/* 2020-02-17 1.4  WLChooi    WMS-12095 - Update Col35 Logic (WL02)           */
/* 2020-05-28 1.5  WLChooi    WMS-13526 - Add Col12-Col20 (WL03)              */
/* 2020-06-04 1.6  LZG        INC1159755 - Temp workaround for NIKEKR         */   
/* 2021-05-06 1.7  WLChooi    WMS-16979 - Show Packdetail based on Codelkup   */
/*                            setup (WL04)                                    */
/* 2021-11-11 1.8  KHKHOR     Added storerkey 'ARK' (JSM-32556)               */    
/* 2022-08-05 1.9  CSCHONG    WMS-20377 Revised field logic (CS03)            */
/* 2022-10-12 2.0  CSCHONG    WMS-20377 fit only print 1 label (CS04)         */
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_KR_shipLabel_CJKE]                               
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
  -- SET ANSI_WARNINGS OFF                       --(CS02)             
                                      
   DECLARE            
      @n_TTLSKUCNT         INT,
      @n_TTLSKUQTY         INT, 
      @n_Page              INT,
      @n_ID                INT, 
      @n_RID               INT, 
      @n_MaxLine           INT,       
      @n_MaxLineRec        INT, 
      @c_OHCompany         NVARCHAR(45),
      @c_OHAddress         NVARCHAR(80),
      @c_OHPhone1          NVARCHAR(80),
      @c_OHZip             NVARCHAR(80),
      @c_ExtOrdkey         NVARCHAR(30),
      @c_Pickslipno        NVARCHAR(20),
      @c_GetPickslipno     NVARCHAR(20),
      @c_STNotes2          NVARCHAR(60),
      @c_PDCartonNo        NVARCHAR(10),
      @c_OHComdescr        NVARCHAR(80),
      @c_OHPhone1descr     NVARCHAR(80),
      @c_OHUDF04descr      NVARCHAR(80),
      @c_OHUDF04           NVARCHAR(80),
      @c_OHMCountry        NVARCHAR(80),
      @c_OHMState          NVARCHAR(80),
      @c_OHUDF03           NVARCHAR(80),
      @c_OHMcity           NVARCHAR(80),
      @c_OHMContact1       NVARCHAR(80),
      @n_CartonNo          INT,
      @c_OHMContact2       NVARCHAR(80),
      @c_OHccity           NVARCHAR(80),
      @c_OHbcity           NVARCHAR(80),
     -- @c_OHMcountry        NVARCHAR(45),
      @c_OHMAdd3           NVARCHAR(80),
      @c_OHMAdd4           NVARCHAR(80),
      @c_labelno           NVARCHAR(20),
      @c_Getlabelno        NVARCHAR(20),
      @n_MAxCarton         INT,
      @c_OHDisPlace        NVARCHAR(30),
      @c_OHNotes           NVARCHAR(80),             --(CS01)
      @c_CLNotes           NVARCHAR(80),             --WL01
      @n_ctnsku            INT = 0,                   --(CS04)
      @c_col45             NVARCHAR(20)=''           --(CS04)
     
      
   DECLARE    
      @c_line01            NVARCHAR(80), 
      @c_SKU01             NVARCHAR(80),  
      @c_SKUDesr01         NVARCHAR(80),  
      @n_qty01             INT,         
      @c_line02            NVARCHAR(80), 
      @c_SKU02             NVARCHAR(80),
      @c_SKUDesr02         NVARCHAR(80),
      @n_qty02             INT,            
      @c_line03            NVARCHAR(80), 
      @c_SKU03             NVARCHAR(80), 
      @c_SKUDesr03         NVARCHAR(80), 
      @n_qty03             INT,

     --CS03 S

      @c_line04            NVARCHAR(80), 
      @c_SKU04             NVARCHAR(80),  
      @c_SKUDesr04         NVARCHAR(80),  
      @n_qty04             INT,         
      @c_line05            NVARCHAR(80), 
      @c_SKU05             NVARCHAR(80),
      @c_SKUDesr05         NVARCHAR(80),
      @n_qty05             INT,            
      @c_line06            NVARCHAR(80), 
      @c_SKU06             NVARCHAR(80), 
      @c_SKUDesr06         NVARCHAR(80), 
      @n_qty06             INT
     --CS03 E

   DECLARE                           
      @c_SQL             NVARCHAR(4000),                
      @c_SQLSORT         NVARCHAR(4000),                
      @c_SQLJOIN         NVARCHAR(4000),                    
      @n_TTLpage         INT          
          
   DECLARE  @d_Trace_StartTime   DATETIME,           
            @d_Trace_EndTime    DATETIME,          
            @c_Trace_ModuleName NVARCHAR(20),           
            @d_Trace_Step1      DATETIME,           
            @c_Trace_Step1      NVARCHAR(20),          
            @c_UserName         NVARCHAR(20)    
            
            
   --WL03 START
   DECLARE
      @n_CntRec            INT,         
      @n_CurrentPage       INT,  
      @n_intFlag           INT,
      @c_SKU               NVARCHAR(80),
      @c_SKUDesr           NVARCHAR(80),
      @n_qty               INT

   SET @n_CurrentPage = 1  
   SET @n_TTLpage =1       
   SET @n_MaxLine = 6                  --CS03   
   SET @n_CntRec = 1    
   SET @n_intFlag = 1  
   --WL03 END         
          
   SET @d_Trace_StartTime = GETDATE()          
   SET @c_Trace_ModuleName = ''          
                
    -- SET RowNo = 0                     
   SET @c_SQL = ''    
   
   --WL04 S
   DECLARE @c_Storerkey        NVARCHAR(15)
         , @c_ShowPackdetail   NVARCHAR(1) = 'N'
   
   SELECT @c_Storerkey = Storerkey
   FROM PACKHEADER (NOLOCK)
   WHERE Pickslipno = @c_Sparm1

   IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK)
              WHERE LISTNAME = 'CJKECUSTID'
              AND Storerkey = @c_Storerkey
              AND UDF02 = 'SKULabel')
   BEGIN
      SET @c_ShowPackdetail = 'Y'
   END
   --WL04 E     
                    
--    IF OBJECT_ID('tempdb..#Result','u') IS NOT NULL        
--      DROP TABLE #Result;        
          
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
          
--      IF OBJECT_ID('tempdb..#CartonContent','u') IS NOT NULL        
--      DROP TABLE #CartonContent;        
        
   CREATE TABLE [#SKULULUContent] (                     
      [ID]                    [INT] IDENTITY(1,1) NOT NULL,
      [Pickslipno]            [NVARCHAR] (20)  NULL,
      [labelno]               [NVARCHAR] (20) NULL, 
      [labellineno]           [NVARCHAR] (10) NULL, 
      [SKU]                   [NVARCHAR] (20) NULL,                                    
      [SDESCR]                [NVARCHAR] (80) NULL,                                              
      [skuqty]                INT NULL,                             
      [Retrieve]              [NVARCHAR] (1) default 'N')               
                    
                           
   IF @b_debug=1                
   BEGIN                  
      PRINT 'start'                  
   END    
      
   SET @c_SKU01 = ''
   SET @c_SKUDesr01 = ''
   SET @n_qty01 = 0
   SET @c_SKU02 = ''
   SET @c_SKUDesr02 = ''
   SET @n_qty02 = 0
   SET @c_SKU03 = ''
   SET @c_SKUDesr03 = ''
   SET @n_qty03 = 0
                                   
   DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   SELECT distinct o.C_Company,ISNULL(o.C_Phone1,''),(ISNULL(o.C_Address1,'') + ISNULL(o.C_Address2,'') + ISNULL(o.C_Address3,'')),
   ISNULL(o.C_Zip,''),ISNULL(ST.Notes2,''),(SUBSTRING(o.C_Company,1,LEN(o.C_Company) - LEN(RIGHT(o.C_Company, 1))) + '*'), 
   (SUBSTRING(o.C_Phone1,1,LEN(o.C_Phone1) - LEN(RIGHT(o.C_Phone1, 4))) + '****'),--7
   (substring(pd.LabelNo,1,4) + '-' + Substring(pd.LabelNo,5,4)  +'-' +  Substring(pd.LabelNo,9,4)), --8
   ISNULL(pd.LabelNo,''),ISNULL(o.m_country,''),ISNULL(o.m_state,''),ISNULL(o.Userdefine03,''),ISNULL(o.m_city,''),       --13
   ISNULL(o.m_contact1,''),pd.CartonNo,o.ExternOrderKey,ISNULL(o.M_contact2,''),ISNULL(o.c_city,''),ISNULL(o.b_city,''),
   ISNULL(o.m_address4,''),pd.LabelNo,MAX(pd.CartonNo),pd.pickslipno,o.DischargePlace,ISNULL(o.m_address3,''),
   SUBSTRING(o.Notes,1,80), ISNULL(CL.Notes,'')                                             --(CS01)  --WL01
   FROM PackHeader AS ph WITH (NOLOCK) 
   JOIN PackDetail AS pd ON pd.PickSlipNo = ph.PickSlipNo 
   JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey  
   JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=o.storerkey  
   LEFT JOIN PACKINFO PIF (NOLOCK) ON PD.CartonNo = PIF.CartonNo AND PD.Pickslipno = PIF.Pickslipno   --WL02
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.Listname = 'CARRIERBOX' AND CL.Code = ISNULL(PIF.CartonType,'') AND CL.Storerkey = PH.Storerkey  --WL01  --WL02
   WHERE pd.pickslipno =@c_Sparm1  AND pd.labelno = @c_Sparm2  
   GROUP BY o.C_Company,ISNULL(o.C_Phone1,''),(ISNULL(o.C_Address1,'') + ISNULL(o.C_Address2,'') + ISNULL(o.C_Address3,'')),
   ISNULL(o.C_Zip,''),ISNULL(ST.Notes2,''),(SUBSTRING(o.C_Company,1,LEN(o.C_Company) - LEN(RIGHT(o.C_Company, 1))) + '*'), 
   (SUBSTRING(o.C_Phone1,1,LEN(o.C_Phone1) - LEN(RIGHT(o.C_Phone1, 4))) + '****'),--7
   (substring(pd.UPC,1,4) + '-' + Substring(pd.UPC,5,4)  +'-' +  Substring(pd.UPC,9,4)), 
   ISNULL(pd.UPC,''),ISNULL(o.m_country,''),ISNULL(o.m_state,''),ISNULL(o.Userdefine03,''),ISNULL(o.m_city,''),
   ISNULL(o.m_contact1,''),pd.CartonNo,o.ExternOrderKey,ISNULL(o.M_contact2,''),ISNULL(o.c_city,''),ISNULL(o.b_city,''),
   ISNULL(o.m_country,''),ISNULL(o.m_address4,''),pd.LabelNo,pd.pickslipno,o.DischargePlace,ISNULL(o.m_address3,''),
   SUBSTRING(o.Notes,1,80),ISNULL(CL.Notes,'')                                              --(CS01) --WL01
        
   OPEN CUR_StartRecLoop                    
               
   FETCH NEXT FROM CUR_StartRecLoop INTO  @c_OHCompany,@c_OHPhone1,@c_OHAddress,@c_OHZip,@c_STNotes2,@c_OHComdescr,
                                          @c_OHPhone1descr,@c_OHUDF04descr,@c_OHUDF04,@c_OHMCountry,
                                          @c_OHMState,@c_OHUDF03,@c_OHMcity ,@c_OHMContact1,@n_CartonNo,@c_ExtOrdkey,@c_OHMContact2,
                                          @c_OHccity,@c_OHbcity,@c_OHMAdd4,@c_labelno, @n_MAxCarton ,@c_Pickslipno ,@c_OHDisPlace,@c_OHMAdd3
                                          ,@c_OHNotes,@c_CLNotes                          --(CS01)    --WL01
                                                       
                 
   WHILE @@FETCH_STATUS <> -1                    
   BEGIN           
          
      IF @b_debug=1                
      BEGIN                  
         PRINT 'Cur start'                  
      END          
          
      INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                          ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                          ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                          ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                          ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                          ,Col55,Col56,Col57,Col58,Col59,Col60)             
      VALUES(@c_OHCompany,@c_OHPhone1,@c_OHAddress,@c_OHZip,@c_STNotes2,@c_OHComdescr,@c_OHPhone1descr,        --7 
             @c_OHUDF04descr,@c_labelno,@c_OHMCountry,@c_OHMState,'','',       --13  
             '','','','','','','',                                             --20       
             @c_OHMAdd3,@c_OHMAdd4,@c_OHMContact1,@n_CartonNo,@c_ExtOrdkey,@c_OHMContact2,       --26
             @c_OHccity,@c_OHbcity,@c_OHDisPlace,@c_OHMAdd4,@c_labelno, @n_MAxCarton,@c_OHMcity,@c_OHNotes,@c_CLNotes,'','','','',   --39  --(CS01)  --WL01
             '','','','','','','','','','',''        --50   
             ,'','','','','','','','',@c_Pickslipno,'O')          
          
          
      IF @b_debug=1                
      BEGIN                
         SELECT * FROM #Result (nolock)                
      END                     
             
          
      FETCH NEXT FROM CUR_StartRecLoop INTO @c_OHCompany,@c_OHPhone1,@c_OHAddress,@c_OHZip,@c_STNotes2,@c_OHComdescr,
                                            @c_OHPhone1descr,@c_OHUDF04descr,@c_OHUDF04,@c_OHMCountry,
                                            @c_OHMState,@c_OHUDF03,@c_OHMcity ,@c_OHMContact1,@n_CartonNo,@c_ExtOrdkey,@c_OHMContact2,
                                            @c_OHccity,@c_OHbcity,@c_OHMAdd4,@c_labelno, @n_MAxCarton,@c_Pickslipno   ,@c_OHDisPlace,@c_OHMAdd3 
                                           ,@c_OHNotes,@c_CLNotes                          --(CS01)    --WL01                
          
   END -- While                     
   CLOSE CUR_StartRecLoop                    
   DEALLOCATE CUR_StartRecLoop 

   --WL04 S
   -- INC1159755 START    
   --DECLARE @c_StorerKey NVARCHAR(10)
   --SELECT @c_StorerKey = StorerKey FROM PackHeader (NOLOCK)  
   --WHERE PickSlipNo = @c_Sparm1
   
   --IF @c_StorerKey NOT IN ('NIKEKR', 'AOS', 'COS')  
   --BEGIN    
   
   IF @c_StorerKey NOT IN ('NIKEKR', 'AOS', 'COS','ARK')  --(JSM-32556) 
      SET @c_ShowPackdetail = 'Y'
    
   IF @c_ShowPackdetail = 'Y'
   BEGIN  
   --WL04 E
      --WL03 START
      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT col09,col59,CAST(col24 AS INT)    
      FROM #Result 
      ORDER BY col59, CAST(col24 AS INT)
      
      OPEN CUR_RowNoLoop   
      
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_LabelNo, @c_Pickslipno, @n_CartonNo 
      
      WHILE @@FETCH_STATUS <> -1 
      BEGIN
         --CS04 S
         SET @n_ctnsku = 0

         SELECT @n_ctnsku = COUNT(DISTINCT PD.sku)
         FROM PACKHEADER PH WITH (NOLOCK)
         JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.PickSlipNo = PD.Pickslipno      
         WHERE PD.PickSlipNo = @c_Pickslipno   
         AND PD.CartonNo = CAST(@n_CartonNo AS INT)
         AND PD.LabelNo = @c_LabelNo
         --CS04 E   


         INSERT INTO #SKULULUContent
         SELECT TOP 6 @c_Pickslipno, @c_LabelNo, PD.LabelLine, PD.SKU, S.DESCR, SUM(PD.Qty), 'N'    --CS04
         FROM PACKHEADER PH WITH (NOLOCK)
         JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.PickSlipNo = PD.Pickslipno      
         JOIN SKU S WITH (NOLOCK) ON S.Sku = PD.SKU AND S.storerkey = PH.Storerkey   
         WHERE PD.PickSlipNo = @c_Pickslipno   
         AND PD.CartonNo = CAST(@n_CartonNo AS INT)
         AND PD.LabelNo = @c_LabelNo
         GROUP BY PD.LabelLine, PD.SKU, S.DESCR
         ORDER BY CAST(PD.LabelLine AS INT)
      
         SET @c_SKU01     = ''
         SET @c_SKUDesr01 = ''
         SET @n_qty01     = ''
         SET @c_SKU02     = ''
         SET @c_SKUDesr02 = ''
         SET @n_qty02     = ''
         SET @c_SKU03     = ''
         SET @c_SKUDesr03 = ''
         SET @n_qty03     = ''
      
       --CS03 S
         SET @c_SKU04     = ''
         SET @c_SKUDesr04 = ''
         SET @n_qty04     = ''
         SET @c_SKU05     = ''
         SET @c_SKUDesr05 = ''
         SET @n_qty05     = ''
         SET @c_SKU06     = ''
         SET @c_SKUDesr06 = ''
         SET @n_qty06     = ''
      --CS03 E

         IF @b_debug = 1
            SELECT * FROM #SKULULUContent
      
         SELECT @n_CntRec = COUNT (1)  
         FROM #SKULULUContent
         WHERE Pickslipno = @c_Pickslipno
         AND LabelNo = @c_LabelNo
         AND Retrieve = 'N'
      
         SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END   
      
         WHILE @n_intFlag <= @n_CntRec             
         BEGIN
            --IF @n_intFlag > @n_MaxLine AND (@n_intFlag % @n_MaxLine) = 1    --CS04 S remove
            --BEGIN 
            --   SET @n_CurrentPage = @n_CurrentPage + 1
      
            --   IF (@n_CurrentPage > @n_TTLpage)   
            --   BEGIN  
            --      BREAK;  
            --   END
            
            --   INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
            --  ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
            --  ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
            --  ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
            --  ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
            --  ,Col55,Col56,Col57,Col58,Col59,Col60)   
            --   SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10,       
            --                Col11,'','','','', '','','','','',
            --                Col21,Col22,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,                
            --                Col31,Col32,Col33,Col34,Col35, '','','','','',                   
            --                '','','','','', '','','','','',                 
            --                '','','','','', '','','',Col59,Col60 
            --   FROM #Result WHERE Col59 <> ''
      
            --   SET @c_SKU01     = ''
            --   SET @c_SKUDesr01 = ''
            --   SET @n_qty01     = ''
            --   SET @c_SKU02     = ''
            --   SET @c_SKUDesr02 = ''
            --   SET @n_qty02     = ''
            --   SET @c_SKU03     = ''
            --   SET @c_SKUDesr03 = ''
            --   SET @n_qty03     = ''


            --    --CS03 S
            --   SET @c_SKU04     = ''
            --   SET @c_SKUDesr04 = ''
            --   SET @n_qty04     = ''
            --   SET @c_SKU05     = ''
            --   SET @c_SKUDesr05 = ''
            --   SET @n_qty05     = ''
            --   SET @c_SKU06     = ''
            --   SET @c_SKUDesr06 = ''
            --   SET @n_qty06     = ''
            ----CS03 E
            --END     --CS04 E
      
            SELECT   @c_SKU      = SKU    
                   , @c_SKUDesr  = SDESCR   
                   , @n_qty      = SKUQty  
             FROM #SKULULUContent 
             WHERE ID = @n_intFlag
      
             IF (@n_intFlag % @n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage  
             BEGIN 
                SET @c_SKU01      = @c_SKU       
                SET @c_SKUDesr01  = @c_SKUDesr     
                SET @n_qty01      = @n_qty
             END   
             ELSE IF (@n_intFlag % @n_MaxLine) = 2 --AND @n_recgrp = @n_CurrentPage  
             BEGIN   
                SET @c_SKU02      = @c_SKU       
                SET @c_SKUDesr02  = @c_SKUDesr     
                SET @n_qty02      = @n_qty         
             END  
             ELSE IF (@n_intFlag % @n_MaxLine) = 3 --AND @n_recgrp = @n_CurrentPage  
             BEGIN   
                SET @c_SKU03      = @c_SKU       
                SET @c_SKUDesr03  = @c_SKUDesr     
                SET @n_qty03      = @n_qty         
             END   
            --CS03 S
             ELSE IF (@n_intFlag % @n_MaxLine) = 4 --AND @n_recgrp = @n_CurrentPage  
             BEGIN   
                SET @c_SKU04      = @c_SKU       
                SET @c_SKUDesr04  = @c_SKUDesr     
                SET @n_qty04      = @n_qty         
             END 
             ELSE IF (@n_intFlag % @n_MaxLine) = 5 --AND @n_recgrp = @n_CurrentPage  
             BEGIN   
                SET @c_SKU05      = @c_SKU       
                SET @c_SKUDesr05  = @c_SKUDesr     
                SET @n_qty05      = @n_qty         
             END   
             ELSE IF (@n_intFlag % @n_MaxLine) = 0 --AND @n_recgrp = @n_CurrentPage  
             BEGIN   
                SET @c_SKU06      = @c_SKU       
                SET @c_SKUDesr06  = @c_SKUDesr     
                SET @n_qty06      = @n_qty         
             END     

            --CS03 E
      
             UPDATE #Result
             SET   Col12 = @c_SKU01
                 , Col13 = @c_SKUDesr01 
                 , Col14 = CASE WHEN CAST(@n_qty01 AS NVARCHAR(80)) = '0' THEN '' ELSE CAST(@n_qty01 AS NVARCHAR(80)) END   
                 , Col15 = @c_SKU02     
                 , Col16 = @c_SKUDesr02    
                 , Col17 = CASE WHEN CAST(@n_qty02 AS NVARCHAR(80)) = '0' THEN '' ELSE CAST(@n_qty02 AS NVARCHAR(80)) END
                 , Col18 = @c_SKU03     
                 , Col19 = @c_SKUDesr03       
                 , Col20 = CASE WHEN CAST(@n_qty03 AS NVARCHAR(80)) = '0' THEN '' ELSE CAST(@n_qty03 AS NVARCHAR(80)) END
                 , col36 = @c_SKU04                                                                                            --CS03 S
                 , Col37 = @c_SKUDesr04 
                 , Col38 = CASE WHEN CAST(@n_qty04 AS NVARCHAR(80)) = '0' THEN '' ELSE CAST(@n_qty04 AS NVARCHAR(80)) END 
                 , col39 = @c_SKU05
                 , Col40 = @c_SKUDesr05 
                 , Col41 = CASE WHEN CAST(@n_qty05 AS NVARCHAR(80)) = '0' THEN '' ELSE CAST(@n_qty05 AS NVARCHAR(80)) END 
                 , col42 = @c_SKU06
                 , Col43 = @c_SKUDesr06 
                 , Col44 = CASE WHEN CAST(@n_qty06 AS NVARCHAR(80)) = '0' THEN '' ELSE CAST(@n_qty06 AS NVARCHAR(80)) END      
                 , Col45 = CAST(@n_ctnsku AS NVARCHAR(20))                                                                     --CS03 E  
            WHERE ID = @n_CurrentPage AND Col59 <> ''
      
            UPDATE #SKULULUContent
            SET Retrieve = 'Y'
            WHERE ID = @n_intFlag
      
            SET @n_intFlag = @n_intFlag + 1
         
            IF @n_intFlag > @n_CntRec  
            BEGIN  
               BREAK;  
            END  
         END
      
         FETCH NEXT FROM CUR_RowNoLoop INTO @c_LabelNo, @c_Pickslipno, @n_CartonNo 
      END
      CLOSE CUR_RowNoLoop
      DEALLOCATE CUR_RowNoLoop
      --WL03 END

   END    
   -- INC1159755 END 
 
   SELECT * from #result WITH (NOLOCK)  
--   WHERE LEN(ISNULL(Col21,'') +  ISNULL(Col22,'') + ISNULL(Col23,'') +                    
--         ISNULL(Col24,'') +  ISNULL(Col25,'') + ISNULL(Col26,'') +            
--         ISNULL(Col27,'') +  ISNULL(Col28,'') +  ISNULL(Col29,'') +            
--         ISNULL(Col30,'')) > 0            
          
   EXIT_SP:            
          
   SET @d_Trace_EndTime = GETDATE()          
   SET @c_UserName = SUSER_SNAME()          
             
   --EXEC isp_InsertTraceInfo           
   --   @c_TraceCode = 'BARTENDER',          
   --   @c_TraceName = 'isp_BT_Bartender_KR_shipLabel_CJKE',          
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
           
                                    
END -- procedure   


GO