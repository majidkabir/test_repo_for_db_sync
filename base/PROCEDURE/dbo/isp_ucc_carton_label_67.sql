SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_67                            */
/* Creation Date:02-NOV-2017                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-3359 -SG - Triple - Carton Packing Label               */
/*                                                                      */
/* Input Parameters: PickSlipNo, CartonNoStart, CartonNoEnd             */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_67                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 14-JUN-2018  CSCHONG  1.1  WMS-5362 - Add new field (CS01)           */
/* 23-Oct-2019  WLChooi  1.2  WMS-10950 - Add new field (WL01)          */
/* 12-AUG-2020  CSCHONG  1.3  WMS-14624 - revised field mapping (CS02)  */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_67] (
	        @c_Storerkey      NVARCHAR(20)  
        ,  @c_PickSlipNo     NVARCHAR(20)
        ,  @c_StartCartonNo  NVARCHAR(20)
        ,  @c_EndCartonNo    NVARCHAR(20)
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_ExternOrderkey  NVARCHAR(150)
         , @c_Address1        NVARCHAR(45)
         , @c_Address2        NVARCHAR(45)
         , @c_Address3        NVARCHAR(45)
         , @c_Address4        NVARCHAR(45)
         , @c_PDLabelNo       NVARCHAR(20)
         , @c_CState          NVARCHAR(45)
         , @c_SKU             NVARCHAR(20)
         , @c_consigneekey    NVARCHAR(45)
         , @n_PDqty           INT
         , @c_Orderkey        NVARCHAR(20)
         , @n_CntSize         INT
			, @n_Page            INT
			, @c_ordkey          NVARCHAR(20)
			, @n_PrnQty          INT
			, @n_MaxId           INT
			, @n_MaxRec          INT
			, @n_getPageno       INT
			, @n_MaxLineno       INT
			, @n_CurrentRec      INT
			--, @c_StorerKey       NVARCHAR(20) 
			, @c_SortCode        NVARCHAR(50)
			, @c_FUDF02          NVARCHAR(30) 
			, @c_FCountry        NVARCHAR(30)
			, @c_FAddress1       NVARCHAR(45)
			, @c_FAddress2       NVARCHAR(45)   
			, @c_Country         NVARCHAR(45)
			, @c_Company         NVARCHAR(45)
			, @c_SCM             NVARCHAR(30)
			, @c_UDF01           NVARCHAR(20)     --CS01
         , @c_Route           NVARCHAR(10)     --WL01


   SET @c_ExternOrderkey  = ''
   SET @c_PDLabelNo       = ''
   SET @c_SKU             = ''
   SET @n_PDqty           = 0
   SET @c_Orderkey        = ''
   SET @n_CntSize         = 1
	SET @n_Page            = 1
	SET @n_PrnQty          = 1
	SET @n_PrnQty          = 1
	SET @n_MaxLineno       = 17   
	SET @c_Address1        = ''         
   SET @c_Route           = ''    --WL01


  CREATE TABLE #TMP_LCartonLABEL67 (
          rowid              int NOT NULL identity(1,1) PRIMARY KEY,
          Pickslipno         NVARCHAR(20) NULL,
          OrdExtOrdKey       NVARCHAR(150) NULL,
          cartonno           INT NULL,
          PDLabelNo          NVARCHAR(20) NULL,
          SortCode           NVARCHAR(30) NULL,
          SKUStyle           NVARCHAR(20) NULL,
          SKUSize            NVARCHAR(50) NULL,
          PDQty              INT,
          Consigneekey       NVARCHAR(20) NULL,
          CADD1              NVARCHAR(45) NULL,
			 CADD2              NVARCHAR(45) NULL,
			 sku                NVARCHAR(20),
          FAdd1              NVARCHAR(45) NULL,
          FAdd2              NVARCHAR(45) NULL,            
          FUDF02             NVARCHAR(45) NULL,
          Fcountry           NVARCHAR(45) NULL,
          CADD3              NVARCHAR(45) NULL,
          CADD4              NVARCHAR(45) NULL,
          CState             NVARCHAR(45) NULL,
		    CCountry	        NVARCHAR(45) NULL,
		    CCompany           NVARCHAR(45) NULL,
		    COO                NVARCHAR(30) NULL,
		    IntermodalVehicle  NVARCHAR(30) NULL,
		    UDF01              NVARCHAR(20) NULL,
          [Route]            NVARCHAR(10) NULL )   --WL01

          SELECT TOP 1 @c_Orderkey = PAH.OrderKey
          FROM PACKHEADER PAH WITH (NOLOCK)
          JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno
          WHERE PAH.Pickslipno = @c_PickSlipNo
          AND PADET.CartonNo between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)

          SET @c_ExternOrderkey = ''

          IF @c_Orderkey = ''
          BEGIN
             SELECT @c_Orderkey = MIN(OH.Orderkey)
                   ,@c_country  = MIN(OH.C_Country)
             FROM PACKHEADER PAH WITH (NOLOCK)
             JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno
             JOIN ORDERS OH WITH (NOLOCK) ON OH.loadkey = PAH.LoadKey
             WHERE PAH.Pickslipno = @c_PickSlipNo
             AND PADET.CartonNo between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)
          END
          ELSE
          BEGIN
             SELECT @c_country = OH.c_country
                   ,@c_ExternOrderkey = OH.ExternOrderKey
             FROM ORDERS OH WITH (NOLOCK)
             WHERE Orderkey = @c_Orderkey
         END	
          
         SET @c_SortCode = ''
          
         SELECT @c_SortCode = C.code
         FROM CODELKUP C WITH (NOLOCK)
         WHERE C.code = @c_Country
         AND C.Storerkey = @c_StorerKey
          
          
         IF @c_SortCode = ''
         BEGIN
            --SET @c_SortCode = @c_Country + RIGHT(@c_Orderkey,4)
            SET @c_SortCode = RTRIM(LTRIM(@c_Country)) + RIGHT(@c_Orderkey, 4)
         END
          
         SELECT @c_Address1       = ISNULL(OH.C_Address1,'')
               ,@c_Address2       = ISNULL(OH.C_Address2,'')
               ,@c_Address3       = ISNULL(OH.C_Address3,'')
               ,@c_Address4       = ISNULL(OH.C_Address4,'')
               ,@c_CState         = ISNULL(OH.C_State,'')
               ,@c_Country        = ISNULL(OH.C_Country,'')
               ,@c_Company        = ISNULL(OH.C_Company,'')
               ,@c_consigneekey   = OH.ConsigneeKey
               ,@c_FUDF02         = ISNULL(F.UserDefine02,'')
               ,@c_FAddress1      = ISNULL(F.Address1,'')
               ,@c_FAddress2      = ISNULL(F.Address2,'')
               ,@c_FCountry       = ISNULL(F.Country,'')
               ,@c_SCM            = ISNULL(OH.IntermodalVehicle,'')
               ,@c_UDF01          = ISNULL(OH.UserDefine01,'')
              --  ,@c_ExternOrderkey = OH.ExternOrderKey
         FROM ORDERS OH WITH (NOLOCK)
         JOIN FACILITY F WITH (NOLOCK) ON F.Facility=OH.Facility
         WHERE OH.OrderKey = @c_Orderkey
          
          
         IF @c_Address1 = ''
         BEGIN
            SELECT @c_Address1 = s.Address1
                  ,@c_Address2 = s.Address2
                  ,@c_Address3 = s.Address3
                  ,@c_Address4 = s.Address4
                  ,@c_CState = s.[State]
            FROM STORER AS s WITH (NOLOCK)
            WHERE s.StorerKey = @c_consigneekey
            AND TYPE = '2'	
         END

         --WL01 Start
         SELECT @c_Route = ISNULL(SUSR1,'')
         FROM STORER (NOLOCK)
         WHERE STORERKEY = @c_consigneekey
         AND TYPE = '2'
         --WL01 End
          
         INSERT INTO #TMP_LCartonLABEL67(Pickslipno,OrdExtOrdKey,cartonno,
                                         PDLabelNo,sortcode,SKUStyle,SKUSize,PDQty,consigneekey,CADD1,CADD2,
                                         sku,FAdd1,FAdd2,FUDF02,Fcountry,CADD3, CADD4,
                                         CState, CCountry, CCompany, COO, IntermodalVehicle, UDF01, [Route])            --(CS01)   --WL01
         SELECT   DISTINCT PAH.Pickslipno
               ,  @c_ExternOrderkey
               ,  PADET.CartonNo
               ,  ISNULL(RIGHT(RTRIM(PADET.Labelno),10),'')                        
               ,  @c_sortcode
               ,  ISNULL(RTRIM(S.Style),'') 
               ,  CASE WHEN ISNULL(c.code2,'') = '' THEN ISNULL(RTRIM(S.Style),'') + '-' + S.busr10 ELSE  S.busr6 END      --CS02
               ,  SUM(PADET.qty)
               ,  @c_consigneekey
               ,  @c_Address1
               ,  @c_Address2
         		,  PADET.SKU
         		,  @c_FAddress1
         		,  @c_FAddress2  
         		,  @c_FUDF02
         		,  @c_FCountry         
         		,  @c_Address3
         		,  @c_Address4    
         		,  @c_CState
         		,  @c_Country
         		,  @c_Company
         		,  LA.Lottable08    
         		,  @c_SCM
         		,  @c_UDF01                     --(CS01)
               ,  @c_Route                     --(WL01)                    
         FROM PACKHEADER PAH WITH (NOLOCK)
         JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno
         JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PADET.Storerkey and S.SKU = PADET.SKU
   
         JOIN 
         
          (SELECT PD.StorerKey, PD.PickSlipNo, PD.SKU, Max(LA.Lottable08) Lottable08,  Count(Distinct LA.Lottable08) Multiple_COO 
          From Pickdetail PD WITH (NOLOCK) Inner Join LotAttribute LA WITH (NOLOCK)
         				ON LA.StorerKey = PD.StorerKey and LA.SKU = PD.SKU and LA.Lot = PD.Lot
         Where PD.StorerKey = @c_StorerKey
         AND PD.PickSlipNo = @c_PickSlipNo
         GROUP BY PD.StorerKey, PD.PickSlipNo, PD.SKU
         HAVING Count(Distinct LA.Lottable08) >= 1) LA ON LA.StorerKey = PADET.StorerKey and LA.PickSlipNo = PADET.PickSlipNo and LA.SKU = PADET.SKU
         /*CS02 START*/
         --LEFT JOIN (SELECT PH.Pickslipno, max(OH.consigneekey) as consigneekey
         -- From PACKHEADER PH WITH (NoLOCK) Join ORDERS OH WITH (NOLOCK)
         --				ON PH.StorerKey = OH.StorerKey and PH.loadkey = OH.Loadkey
         --Where OH.StorerKey = @c_StorerKey
         --AND PH.PickSlipNo = @c_PickSlipNo
         --GROUP BY PH.Pickslipno) CON ON CON.Pickslipno = PAH.Pickslipno 
         JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = PAH.Orderkey
         LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CUSTSKU' AND C.storerkey = PAH.Storerkey AND C.code2 = OH.consigneekey
         /*Cs02 END*/
         WHERE PAH.Pickslipno = @c_PickSlipNo
         AND   PAH.Storerkey = @c_StorerKey
         AND PADET.CartonNo between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)
         GROUP BY PAH.Pickslipno,PADET.CartonNo,ISNULL(RIGHT(RTRIM(PADET.Labelno),10),''),
                 ISNULL(RTRIM(S.Style),'') ,CASE WHEN ISNULL(c.code2,'') = '' THEN ISNULL(RTRIM(S.Style),'') + '-' +(S.busr10) ELSE (S.busr6) END ,  --CS02
                  PADET.SKU, LA.Lottable08

   /*
   UNION ALL
   
   SELECT DISTINCT  PAH.Pickslipno
         ,  @c_ExternOrderkey
         ,  PADET.CartonNo
         ,  ISNULL(RIGHT(RTRIM(PADET.Labelno),10),'')                        
         ,  @c_sortcode
         ,  ISNULL(RTRIM(S.Style),'')
         ,  ISNULL(RTRIM(S.Size),'')
         ,  SUM(LA.qty)
         ,  @c_consigneekey
         ,  @c_Address1
         ,  @c_Address2
			,  PADET.SKU
			,  @c_FAddress1
			,  @c_FAddress2  
			,  @c_FUDF02
			,  @c_FCountry         
			,  @c_Address3
			,  @c_Address4    
			,  @c_CState
			,@c_Country
			,@c_Company
			,LA.Lottable08    
			,@c_SCM
			                                  
   FROM PACKHEADER PAH WITH (NOLOCK)
   JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PADET.Storerkey and S.SKU = PADET.SKU
   
   JOIN 
   
    (SELECT PD.StorerKey, PD.PickSlipNo, PD.SKU, PD.Qty, LA.Lottable08, Count(Distinct LA.Lottable08) Multiple_COO 
    From Pickdetail PD WITH (NOLOCK) Inner Join LotAttribute LA WITH (NOLOCK)
					ON LA.StorerKey = PD.StorerKey and LA.SKU = PD.SKU and LA.Lot = PD.Lot
	Where PD.StorerKey = @c_StorerKey
	AND PD.PickSlipNo = @c_PickSlipNo
	GROUP BY PD.StorerKey, PD.PickSlipNo, PD.SKU, PD.QTY, LA.Lottable08
	HAVING Count(Distinct LA.Lottable08) > 1) LA ON LA.StorerKey = PADET.StorerKey and LA.PickSlipNo = PADET.PickSlipNo and LA.SKU = PADET.SKU
	

   WHERE PAH.Pickslipno = @c_PickSlipNo
   AND   PAH.Storerkey = @c_StorerKey
   AND PADET.CartonNo between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)
   GROUP BY PAH.Pickslipno,PADET.CartonNo,ISNULL(RIGHT(RTRIM(PADET.Labelno),10),''),
            ISNULL(RTRIM(S.Style),''),ISNULL(RTRIM(S.Size),''),PADET.SKU, LA.Lottable08
   */ 
         ORDER BY ISNULL(RIGHT(RTRIM(PADET.Labelno),10),''),PADET.CartonNo, LA.Lottable08



         SELECT Pickslipno, OrdExtOrdKey, cartonno, PDLabelNo, sortcode, SKUStyle, SKUSize, PDQty,
                consigneekey = CCompany, CADD1, CADD2, sku, FAdd1, FAdd2, FUDF02, Fcountry, CADD3, 
                CADD4, CState = CCountry, COO, 
                IntermodalVehicle SCM,
                UDF01, [Route]                        --(CS01)     --WL01
			   --SCM = '123456789012345678901234567890'  
         FROM   #TMP_LCartonLABEL67
         ORDER BY Pickslipno, cartonno, SKUStyle, SKUSize

END
SET QUOTED_IDENTIFIER OFF 

GO