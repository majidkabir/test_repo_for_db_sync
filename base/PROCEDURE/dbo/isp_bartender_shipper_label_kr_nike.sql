SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: LFL                                                             */                 
/* Purpose: isp_Bartender_Shipper_Label_KR_NIKE                               */
/*          Copy from isp_Bartender_Shipper_Label_KR_01                       */                   
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2021-09-29 1.0  WLChooi    Created (WMS-18054) - DevOps Combine Script     */
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_Shipper_Label_KR_NIKE]                               
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
  -- SET ANSI_WARNINGS OFF                              
                                      
   DECLARE            
      @c_getPickslipno     NVARCHAR(10),                        
      @c_getlabelno        NVARCHAR(20),          
      @C_RECEIPTKEY        NVARCHAR(11),          
      @c_Pickslipno        NVARCHAR(10),     
      @n_TTLCNT            INT,
      @n_TTLSKUQTY         INT, 
      @n_Page              INT,
      @n_ID                INT, 
      @n_RID               INT, 
      @n_MaxLine           INT,       
      @n_MaxLineRec        INT, 
      @c_StateCity         NVARCHAR(80),
      @c_OHCompany         NVARCHAR(45),
      @c_OHAddress1        NVARCHAR(45),
      @c_OHAddress2        NVARCHAR(45),
      @c_OHAddress3        NVARCHAR(45),
      @c_OHAddress4        NVARCHAR(45),
      @c_ExtOrdkey         NVARCHAR(30),
      @c_billtokey         NVARCHAR(20),
      @c_consigneekey      NVARCHAR(20),
      @c_czip              NVARCHAR(45),
      @c_PDCartonNo        NVARCHAR(10),
      @c_FacilityAdd       NVARCHAR(30),
      @c_labelno           NVARCHAR(20),
      @n_CurrentPage       INT,               
      @n_intFlag           INT,                
      @n_RecCnt            INT,
      @n_ttlqty            INT                
      
  DECLARE    
      @c_line01            NVARCHAR(80), 
      @c_Style             NVARCHAR(80),     
      @c_Scolor            NVARCHAR(80),
      @c_Ssize             NVARCHAR(80),
      @c_SMEASM            NVARCHAR(80),  
      @n_qty               INT,              
      @c_Style01           NVARCHAR(80),  
      @c_Scolor01          NVARCHAR(80),  
      @c_SSize01           NVARCHAR(80),
      @c_SMEASM01          NVARCHAR(80),    
      @n_qty01             INT,         
      @c_line02            NVARCHAR(80), 
      @c_Style02           NVARCHAR(80),  
      @c_Scolor02          NVARCHAR(80),  
      @c_SSize02           NVARCHAR(80),
      @c_SMEASM02          NVARCHAR(80),   
      @n_qty02             INT,            
      @c_line03            NVARCHAR(80), 
      @c_Style03           NVARCHAR(80),  
      @c_Scolor03          NVARCHAR(80),  
      @c_SSize03           NVARCHAR(80),
      @c_SMEASM03          NVARCHAR(80),   
      @n_qty03             INT,         
      @c_line04            NVARCHAR(80), 
      @c_Style04           NVARCHAR(80),  
      @c_Scolor04          NVARCHAR(80),  
      @c_SSize04           NVARCHAR(80),
      @c_SMEASM04          NVARCHAR(80),   
      @n_qty04             INT,          
      @c_line05            NVARCHAR(80),  
      @c_Style05           NVARCHAR(80),  
      @c_Scolor05          NVARCHAR(80),  
      @c_SSize05           NVARCHAR(80),
      @c_SMEASM05          NVARCHAR(80),   
      @n_qty05             INT,       
      @c_line06            NVARCHAR(80),
      @c_Style06           NVARCHAR(80),  
      @c_Scolor06          NVARCHAR(80),  
      @c_SSize06           NVARCHAR(80),
      @c_SMEASM06          NVARCHAR(80),   
      @n_qty06             INT,         
      @c_line07            NVARCHAR(80),    
      @c_Style07           NVARCHAR(80),  
      @c_Scolor07          NVARCHAR(80),  
      @c_SSize07           NVARCHAR(80),
      @c_SMEASM07          NVARCHAR(80),   
      @n_qty07             INT,   
      @n_ttlPqty           INT
      
  
   DECLARE                           
      @c_SQL             NVARCHAR(4000),                
      @c_SQLSORT         NVARCHAR(4000),                
      @c_SQLJOIN         NVARCHAR(4000),                    
      @n_TTLpage         INT,
      @n_CntRec          INT                          
          
   DECLARE  @d_Trace_StartTime  DATETIME,           
            @d_Trace_EndTime    DATETIME,          
            @c_Trace_ModuleName NVARCHAR(20),           
            @d_Trace_Step1      DATETIME,           
            @c_Trace_Step1      NVARCHAR(20),          
            @c_UserName         NVARCHAR(20),
            @n_getskugroup      INT,
            @n_GetAltSKUInfo    INT,
            @c_OHNotes          NVARCHAR(80)  
          
   SET @d_Trace_StartTime = GETDATE()          
   SET @c_Trace_ModuleName = ''          
                
   -- SET RowNo = 0                     
   SET @c_SQL = ''   
   SET @n_ttlPqty = 0           
   SET @n_CurrentPage = 1  
   SET @n_intFlag = 1     
   SET @n_RecCnt = 1        
   SET @n_getskugroup = 0 
   SET @n_GetAltSKUInfo = 0

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

   CREATE TABLE [#TEMPSKUContent] (                     
      [ID]                    [INT] IDENTITY(1,1) NOT NULL,
      [Pickslipno]            [NVARCHAR] (20)  NULL,
      cartonno                [NVARCHAR] (10) NULL,  
      [Style]                 [NVARCHAR] (20) NULL,                                    
      [SColor]                [NVARCHAR] (10) NULL,   
      [SSize]                 [NVARCHAR] (10) NULL, 
      [SMeasurement]          [NVARCHAR] (10) NULL,                                          
      [skuqty]                INT NULL,        
      [ttlctn]                INT,                     
      [Retrieve]              [NVARCHAR] (1) default 'N')               
                                         
   IF @b_debug=1                
   BEGIN                  
      PRINT 'start'                  
   END          
          
   DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   SELECT DISTINCT CASE WHEN (ISNULL(ST.[state],'') + ISNULL(ST.city,'')) <> '' THEN (ISNULL(ST.[state],'') + ISNULL(ST.city,'')) 
                        ELSE (ISNULL(O.c_state,'') + ISNULL(O.c_city,'')) END as StateCity,
                   O.ExternOrderKey,O.C_Company,O.billtokey,O.consigneekey,pd.labelno,ISNULL(ST.Zip,''),
                   CASE WHEN ISNULL(ST.Address1,'')  <> '' THEN ISNULL(ST.Address1,'') 
                        ELSE ISNULL(O.c_Address1,'') END as OHAddress1,
                   CASE WHEN ISNULL(ST.Address2,'')  <> '' THEN ISNULL(ST.Address2,'') 
                        ELSE ISNULL(O.c_Address2,'') END as OHAddress2,
                   CASE WHEN ISNULL(ST.Address3,'')  <> '' THEN ISNULL(ST.Address3,'') 
                        ELSE ISNULL(O.c_Address3,'') END as OHAddress3,
                   CASE WHEN ISNULL(ST.Address4,'')  <> '' THEN ISNULL(ST.Address4,'') 
                        ELSE ISNULL(O.c_Address4,'') END as OHAddress4, 
                   SUM(pd.Qty) AS ttlqty, ph.PickSlipNo, SUBSTRING(ISNULL(O.notes,''),1,80)                                             
   FROM PackHeader AS ph WITH (NOLOCK) 
   JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo 
   JOIN ORDERS AS o WITH (NOLOCK) ON O.OrderKey = ph.OrderKey  
   LEFT JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=O.consigneekey  
   JOIN FACILITY F WITH (NOLOCK) ON F.facility = O.facility 
   JOIN loadplandetail lpd WITH (NOLOCK) ON lpd.LoadKey=O.LoadKey AND lpd.OrderKey=O.OrderKey
   WHERE pd.pickslipno =@c_Sparm1  AND pd.labelno = @c_Sparm2  
   GROUP BY CASE WHEN (ISNULL(ST.[state],'') + ISNULL(ST.city,'')) <> '' THEN (ISNULL(ST.[state],'') + ISNULL(ST.city,'')) 
                 ELSE (ISNULL(O.c_state,'') + ISNULL(O.c_city,'')) END ,
            O.ExternOrderKey,O.C_Company,O.billtokey,O.consigneekey,pd.labelno,ISNULL(ST.Zip,''),
            CASE WHEN ISNULL(ST.Address1,'')  <> '' THEN ISNULL(ST.Address1,'') 
                 ELSE ISNULL(O.c_Address1,'') END,
            CASE WHEN ISNULL(ST.Address2,'')  <> '' THEN ISNULL(ST.Address2,'') 
                 ELSE ISNULL(O.c_Address2,'') END,
            CASE WHEN ISNULL(ST.Address3,'')  <> '' THEN ISNULL(ST.Address3,'') 
                 ELSE ISNULL(O.c_Address3,'') END,
            CASE WHEN ISNULL(ST.Address4,'')  <> '' THEN ISNULL(ST.Address4,'') 
                 ELSE ISNULL(O.c_Address4,'') END, ph.PickSlipNo, SUBSTRING(ISNULL(O.notes,''),1,80)               
    
          
   OPEN CUR_StartRecLoop                    
               
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_Statecity,@c_ExtOrdKey,@c_OHCompany,@c_billtokey,@c_consigneekey,@c_labelno,@c_czip ,
                                         @c_OHAddress1, @c_OHAddress2,@c_OHAddress3,@c_OHAddress4,@n_ttlqty,@c_Pickslipno,@c_OHNotes
                                                       
                 
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
      VALUES(@c_Statecity,@c_ExtOrdKey,@c_OHCompany,@c_billtokey,@c_consigneekey,@c_labelno,@c_czip,          
             @c_OHAddress1,@c_OHAddress2,@c_OHAddress3,@c_OHAddress4,'','',          
             '','','','','','','',           
             '','','','','','','','','','','','','','','','','','','','','','','','','','','','',CONVERT(NVARCHAR(10),@n_ttlqty),@c_OHNotes      
             ,'','','','','','','','',@c_Pickslipno,'O')          
          
          
      IF @b_debug=1                
      BEGIN                
         SELECT * FROM #Result (nolock)                
      END           
          
      SET @n_MaxLine    = 7
      SET @n_MaxLineRec = 7
      SET @n_TTLpage    = 1       

      IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK)
                 WHERE listname = 'CTNLBL' AND Code = 'skugroup'
                 AND Storerkey = @c_Sparm5)
      BEGIN
         SET @n_getskugroup = 1
      END

      IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK)
                 WHERE listname = 'CTNLBL' AND Code = 'GetAltSKUInfo'
                 AND Storerkey = @c_Sparm5)
      BEGIN
         SET @n_GetAltSKUInfo = 1
      END
        
      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                      
                        
      SELECT DISTINCT col59,col06   
      FROM #Result 
      WHERE col59 = @c_Sparm1 
      AND col06 = @c_Sparm2               
      ORDER BY col59,Col06      
               
      OPEN CUR_RowNoLoop                    
                  
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_getPickslipno,@c_getlabelno
                    
      WHILE @@FETCH_STATUS <> -1               
      BEGIN   
         IF @n_GetAltSKUInfo = 1
         BEGIN
            INSERT INTO #TEMPSKUContent
            (
               -- ID -- this column value is auto-generated
               Pickslipno,
               cartonno,
               Style,
               SColor,
               SSize,
               SMeasurement,
               skuqty,
               Retrieve,
               ttlctn
            )               
            SELECT PH.PickSlipNo, PD.cartonno,
                   ALTSKU.style,
                   ALTSKU.color, ALTSKU.size, 
                   CASE WHEN @n_getskugroup = 1 THEN ALTSKU.skugroup ELSE ALTSKU.Measurement END,
                   PD.Qty, 'N',
                   CASE WHEN PH.[status] <> '0' THEN @c_Sparm4 ELSE 0 END
            FROM PackHeader AS PH WITH (NOLOCK) 
            JOIN PackDetail AS PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo 
            JOIN ORDERS AS O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey  
            JOIN Storer ST WITH (NOLOCK) ON ST.storerkey = O.storerkey 
            JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.sku = PD.SKU
            OUTER APPLY (SELECT TOP 1 S1.Style, S1.Color, S1.Size, S1.SKUGROUP, S1.Measurement
                         FROM SKU S1 (NOLOCK)
                         JOIN SKU S2 (NOLOCK) ON S1.ALTSKU = S2.ALTSKU
                         WHERE S1.StorerKey = 'NIKEKRB'
                         AND S2.StorerKey = PH.StorerKey
                         AND S2.SKU = S.SKU ) AS ALTSKU
            WHERE PD.pickslipno = @c_getPickslipno AND PD.labelno = @c_labelno  
            ORDER BY PH.PickSlipNo, PD.cartonno,
                     ALTSKU.style,
                     ALTSKU.color, ALTSKU.size,
                     CASE WHEN @n_getskugroup = 1 THEN ALTSKU.skugroup ELSE ALTSKU.Measurement END

         END                
         ELSE IF @n_getskugroup = 1
         BEGIN
            INSERT INTO #TEMPSKUContent
            (
               -- ID -- this column value is auto-generated
               Pickslipno,
               cartonno,
               Style,
               SColor,
               SSize,
               SMeasurement,
               skuqty,
               Retrieve,
               ttlctn
            )               
            SELECT PH.PickSlipNo, PD.cartonno,
                   S.style,
                   S.color, S.size, S.skugroup, PD.Qty, 'N',
                   CASE WHEN PH.[status] <> '0' THEN @c_Sparm4 ELSE 0 END
            FROM PackHeader AS PH WITH (NOLOCK) 
            JOIN PackDetail AS PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo 
            JOIN ORDERS AS O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey  
            JOIN Storer ST WITH (NOLOCK) ON ST.storerkey = O.storerkey 
            JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.sku = PD.SKU
            OUTER APPLY (SELECT TOP 1 S1.Style
                         FROM SKU S1 (NOLOCK)
                         JOIN SKU S2 (NOLOCK) ON S1.ALTSKU = S2.ALTSKU
                         WHERE S1.StorerKey = 'NIKEKRB'
                         AND S2.StorerKey = PH.StorerKey
                         AND S2.SKU = S.SKU ) AS ALTSKU
            WHERE PD.pickslipno = @c_getPickslipno AND PD.labelno = @c_labelno  
            ORDER BY PH.PickSlipNo, PD.cartonno,
                     CASE WHEN @n_GetAltSKUInfo = 1 THEN ISNULL(ALTSKU.Style,'') ELSE S.style END,
                     S.color, S.size, S.skugroup    

         END
         ELSE
         BEGIN
              
            INSERT INTO #TEMPSKUContent
            (
               -- ID -- this column value is auto-generated
               Pickslipno,
               cartonno,
               Style,
               SColor,
               SSize,
               SMeasurement,
               skuqty,
               Retrieve,
               ttlctn
            )               
            SELECT PH.PickSlipNo, PD.cartonno,
                   S.style,
                   S.color, S.size, S.Measurement, PD.Qty, 'N',
                   CASE WHEN PH.[status] <> '0' THEN @c_Sparm4 ELSE 0 END
            FROM PackHeader AS PH WITH (NOLOCK) 
            JOIN PackDetail AS PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo 
            JOIN ORDERS AS O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey  
            JOIN Storer ST WITH (NOLOCK) ON ST.storerkey = O.storerkey 
            JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.sku = PD.SKU
            OUTER APPLY (SELECT TOP 1 S1.Style
                         FROM SKU S1 (NOLOCK)
                         JOIN SKU S2 (NOLOCK) ON S1.ALTSKU = S2.ALTSKU
                         WHERE S1.StorerKey = 'NIKEKRB'
                         AND S2.StorerKey = PH.StorerKey
                         AND S2.SKU = S.SKU ) AS ALTSKU
            WHERE PD.pickslipno = @c_getPickslipno AND PD.labelno = @c_labelno  
            ORDER BY PH.PickSlipNo, PD.cartonno,
                     S.style,
                     S.color, S.size, S.Measurement      
         END 
                        
         IF @b_debug = '1'              
         BEGIN              
            SELECT 'carton',* FROM [#TEMPSKUContent]          
         END              
            
         SET @c_line01     = ''
         SET @c_Style01    = ''
         SET @c_Scolor01   = ''
         SET @c_SSize01    = ''
         SET @c_SMEASM01   = ''
         SET @n_qty01      = 0       
         SET @c_line02     = ''
         SET @c_Style02    = ''
         SET @c_Scolor02   = ''
         SET @c_SSize02    = ''
         SET @c_SMEASM02   = ''
         SET @n_qty02      = 0          
         SET @c_line03     = ''
         SET @c_Style03    = ''
         SET @c_Scolor03   = ''
         SET @c_SSize03    = ''
         SET @c_SMEASM03   = ''
         SET @n_qty03      = 0       
         SET @c_line04     = ''
         SET @c_Style04    = ''
         SET @c_Scolor04   = ''
         SET @c_SSize04    = ''
         SET @c_SMEASM04   = ''
         SET @n_qty04      = 0        
         SET @c_line05     = ''
         SET @c_Style05    = ''
         SET @c_Scolor05   = ''
         SET @c_SSize05    = ''
         SET @c_SMEASM05   = ''
         SET @n_qty05      = 0      
         SET @c_line06     = ''
         SET @c_Style06    = ''
         SET @c_Scolor06   = ''
         SET @c_SSize06    = ''
         SET @c_SMEASM06   = ''
         SET @n_qty06       = 0       
         SET @c_line07     = ''
         SET @c_Style07    = ''
         SET @c_Scolor07   = ''
         SET @c_SSize07    = ''
         SET @c_SMEASM07   = ''
         SET @n_qty07      = 0 
         SET @n_TTLCNT     = 0
         SET @c_PDCartonNo = ''
          
         SELECT @n_CntRec = COUNT (1)
         FROM [#TEMPSKUContent]
         WHERE Pickslipno = @c_getPickslipno
         AND Retrieve = 'N' 
      
         SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine )  
              
         IF @b_debug = '1'              
         BEGIN             
            SELECT * FROM  #TEMPSKUContent  WITH (NOLOCK)  WHERE Retrieve='N'         
            SELECT   @n_CntRec '@n_CntRec',@n_TTLpage '@n_TTLpage'        
         END  
         
         WHILE @n_intFlag<= @n_CntRec
         BEGIN
            SELECT   @c_style = c.style
                    ,@c_scolor = c.Scolor
                    ,@c_SSize = c.ssize
                    ,@c_SMEASM = c.SMeasurement 
                    ,@n_qty = c.skuqty 
                    ,@n_TTLCNT = c.ttlctn 
                    ,@c_PDCartonNo = c.cartonno
            FROM  #TEMPSKUContent c WITH (NOLOCK) 
            WHERE id = @n_intFlag
            
            IF (@n_intFlag%@n_MaxLine) = 1
            BEGIN
               SET    @c_style01   = @c_style
               SET    @c_Scolor01  = @c_scolor 
               SET    @c_SSize01   = @c_Ssize
               SET    @c_SMEASM01  = @c_SMEASM
               SET    @n_qty01     = @n_qty         
            END   
            ELSE IF (@n_intFlag%@n_MaxLine) = 2
            BEGIN
               SET    @c_style02   = @c_style
               SET    @c_Scolor02  = @c_scolor 
               SET    @c_SSize02   = @c_Ssize
               SET    @c_SMEASM02  = @c_SMEASM  
               SET     @n_qty02= @n_qty           
            END  
            ELSE IF (@n_intFlag%@n_MaxLine) = 3
            BEGIN
               SET    @c_style03   = @c_style
               SET    @c_Scolor03  = @c_scolor 
               SET    @c_SSize03   = @c_Ssize
               SET    @c_SMEASM03  = @c_SMEASM 
               SET    @n_qty03 = @n_qty          
            END  
            ELSE IF (@n_intFlag%@n_MaxLine) = 4
            BEGIN
               SET    @c_style04   = @c_style
               SET    @c_Scolor04  = @c_scolor 
               SET    @c_SSize04   = @c_Ssize
               SET    @c_SMEASM04  = @c_SMEASM 
               SET    @n_qty04 = @n_qty          
            END   
            ELSE IF (@n_intFlag%@n_MaxLine) = 5
            BEGIN
               SET    @c_style05   = @c_style
               SET    @c_Scolor05  = @c_scolor 
               SET    @c_SSize05   = @c_Ssize
               SET    @c_SMEASM05  = @c_SMEASM 
               SET    @n_qty05= @n_qty          
            END  
            ELSE IF (@n_intFlag%@n_MaxLine) = 6
            BEGIN
               SET    @c_style06   = @c_style
               SET    @c_Scolor06  = @c_scolor 
               SET    @c_SSize06   = @c_Ssize
               SET    @c_SMEASM06  = @c_SMEASM
               SET    @n_qty06 = @n_qty           
            END   
            ELSE IF (@n_intFlag%@n_MaxLine) = 0
            BEGIN
               SET    @c_style07   = @c_style
               SET    @c_Scolor07 = @c_scolor 
               SET    @c_SSize07   = @c_Ssize
               SET    @c_SMEASM07  = @c_SMEASM
               SET    @n_qty07     = @n_qty            
            END  
       
            SET @n_ttlPqty = (@n_qty01+@n_qty02+@n_qty03+@n_qty04+@n_qty05+@n_qty06+@n_qty07)

            IF (@n_RecCnt=@n_MaxLine) OR (@n_intFlag = @n_CntRec)     
            BEGIN
               UPDATE #Result                    
               SET Col12 = @c_style01,           
                   Col13 = @c_Scolor01,           
                   Col14 = @c_SSize01,          
                   Col15 = @c_SMEASM01,          
                   Col16 = CASE WHEN @n_qty01 > 0 THEN CONVERT(NVARCHAR(5),@n_qty01) ELSE '' END,          
                   Col17 = @c_PDCartonNo,          
                   Col18 = CASE WHEN @n_TTLCNT > 0 THEN CONVERT(NVARCHAR(10),@n_TTLCNT) ELSE '' END,
                   Col19 = @c_style02,
                   Col20 = @c_Scolor02,
                   Col21 = @c_SSize02,
                   Col22 = @c_SMEASM02,
                   col23 = CASE WHEN @n_qty02 > 0 THEN CONVERT(NVARCHAR(5),@n_qty02) ELSE '' END  ,
                   Col24 = @c_style03,
                   Col25 = @c_Scolor03,
                   Col26 = @c_SSize03,
                   col27 = @c_SMEASM03,
                   Col28 = CASE WHEN @n_qty03 > 0 THEN CONVERT(NVARCHAR(5),@n_qty03) ELSE '' END  ,
                   Col29 = @c_style04,
                   Col30 = @c_Scolor04,
                   col31 = @c_SSize04,
                   Col32 = @c_SMEASM04,
                   col33 = CASE WHEN @n_qty04 > 0 THEN CONVERT(NVARCHAR(5),@n_qty04) ELSE '' END,
                   Col34 = @c_style05,
                   col35 = @c_Scolor05,
                   Col36 = @c_SSize05,
                   col37 = @c_SMEASM05,
                   Col38 = CASE WHEN @n_qty05 > 0 THEN CONVERT(NVARCHAR(5),@n_qty05) ELSE '' END ,
                   col39 = @c_style06,
                   col40 = @c_Scolor06,
                   col41 = @c_SSize06,
                   col42 = @c_SMEASM06,
                   col43 = CASE WHEN @n_qty06 > 0 THEN CONVERT(NVARCHAR(5),@n_qty06) ELSE '' END  ,
                   col44 = @c_style07,
                   col45 = @c_Scolor07,
                   col46 = @c_SSize07,
                   col47 = @c_SMEASM07,
                   col48 = CASE WHEN @n_qty07 > 0 THEN CONVERT(NVARCHAR(5),@n_qty07) ELSE '' END  
               WHERE col59 = @c_getPickslipno AND col06 = @c_getlabelno 
               AND id = @n_CurrentPage 
       
               SET @n_RecCnt = 0
          
            END 

            IF @n_RecCnt = 0 AND (@n_intFlag<@n_CntRec) --@n_RecCnt = 0 AND (@n_intFlag<@n_CntRec)--(@n_intFlag%@n_MaxLine) = 0 AND (@n_intFlag>@n_MaxLine)
            BEGIN

               SET @n_CurrentPage = @n_CurrentPage + 1   
              
               INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                                   ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                                   ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                                   ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                                   ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                                   ,Col55,Col56,Col57,Col58,Col59,Col60)             
               SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,col07,col08,col09,col10,                 
                            col11,'','','','', '',col17,col18,'','',              
                            '','','','','', '','','','','',              
                            '','','','','', '','','','','',                 
                            '','','','','', '','','',Col49,Col50,               
                            '','','','','', '','','',Col59,''
               FROM  #Result 
               WHERE Col60 = 'O'   
               AND col59 = @c_getPickslipno AND col06 = @c_getlabelno                 
         
               SET @c_line01     = ''
               SET @c_Style01    = ''
               SET @c_Scolor01   = ''
               SET @c_SSize01    = ''
               SET @c_SMEASM01   = ''
               SET @n_qty01      = 0       
               SET @c_line02     = ''
               SET @c_Style02    = ''
               SET @c_Scolor02   = ''
               SET @c_SSize02    = ''
               SET @c_SMEASM02   = ''
               SET @n_qty02      = 0          
               SET @c_line03     = ''
               SET @c_Style03    = ''
               SET @c_Scolor03   = ''
               SET @c_SSize03    = ''
               SET @c_SMEASM03   = ''
               SET @n_qty03      = 0       
               SET @c_line04     = ''
               SET @c_Style04    = ''
               SET @c_Scolor04   = ''
               SET @c_SSize04    = ''
               SET @c_SMEASM04   = ''
               SET @n_qty04      = 0        
               SET @c_line05     = ''
               SET @c_Style05    = ''
               SET @c_Scolor05   = ''
               SET @c_SSize05    = ''
               SET @c_SMEASM05   = ''
               SET @n_qty05      = 0      
               SET @c_line06     = ''
               SET @c_Style06    = ''
               SET @c_Scolor06   = ''
               SET @c_SSize06    = ''
               SET @c_SMEASM06   = ''
               SET @n_qty06       = 0       
               SET @c_line07     = ''
               SET @c_Style07    = ''
               SET @c_Scolor07   = ''
               SET @c_SSize07    = ''
               SET @c_SMEASM07   = ''
               SET @n_qty07      = 0 
              
            END       
         
            SET @n_intFlag = @n_intFlag + 1 
            SET @n_RecCnt = @n_RecCnt + 1
         END               
   
         FETCH NEXT FROM CUR_RowNoLoop INTO @c_getPickslipno,@c_getlabelno                      
      END -- While                     
      CLOSE CUR_RowNoLoop                    
      DEALLOCATE CUR_RowNoLoop                
             
      FETCH NEXT FROM CUR_StartRecLoop INTO @c_Statecity,@c_ExtOrdKey,@c_OHCompany,@c_billtokey,@c_consigneekey,@c_labelno,@c_czip ,
                                            @c_OHAddress1, @c_OHAddress2,@c_OHAddress3,@c_OHAddress4,@n_ttlqty,@c_Pickslipno,@c_OHNotes           
          
   END -- While                     
   CLOSE CUR_StartRecLoop                    
   DEALLOCATE CUR_StartRecLoop            
       
   SELECT * from #result WITH (NOLOCK)           
          
   EXIT_SP:                                         
END -- procedure   

GO