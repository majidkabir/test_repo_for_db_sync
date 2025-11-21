SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: isp_Delivery_Note43_RDT                                 */
/* Creation Date: 13-Apr-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-12725 [KR]SouthCape_Packing List_Datawindow_NEW         */
/*        :                                                             */
/* Called By: r_dw_Delivery_Note43_RDT                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 04-OCT-2022  Mingle    1.0 WMS-20904 add new mappings(ML01)          */
/************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note43_RDT]
            @c_Orderkey       NVARCHAR(10)
           ,@c_StartCartonNo  NVARCHAR(10) = '0'
           ,@c_EndCartonNo    NVARCHAR(10) = '0'
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @b_Success         INT
         , @n_Err             INT
         , @c_Errmsg          NVARCHAR(255)

         , @c_ExternOrderKey  NVARCHAR(50)
         , @c_Storerkey       NVARCHAR(15)

         , @c_RptLogo         NVARCHAR(255)
         , @c_ecomflag        NVARCHAR(50)
         , @n_MaxLineno       INT
         , @n_MaxId           INT
         , @n_MaxRec          INT
         , @n_CurrentRec      INT
         , @c_recgroup        INT	--ML01
			, @n_NoOfLine        INT	--ML01

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1
   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @c_Errmsg    = ''
	SET @n_MaxLineno = 30
   SET @n_MaxRec = 0
	SET @n_NoOfLine = 30	--ML01


    CREATE TABLE #DELNOTE43RDT(
   RowNo        INT NOT NULL IDENTITY(1,1)
  ,Orderkey     NVARCHAR(20)
  ,C_Company    NVARCHAR(45)
  ,C_Addresses  NVARCHAR(255)
  ,Contact2     NVARCHAR(60)
  ,labelno      NVARCHAR(20)
  ,C01          NVARCHAR(150)
  ,C02          NVARCHAR(150)
  ,C03          NVARCHAR(150)
  ,SKU          NVARCHAR(20)
  ,SDESCR       NVARCHAR(255)
  ,C04          NVARCHAR(150)
  ,C05          NVARCHAR(150)
  ,Qty          INT
  ,C06          NVARCHAR(150)
  ,C07          NVARCHAR(150)
  ,C08          NVARCHAR(150)
  ,C09          NVARCHAR(150)
  ,C10          NVARCHAR(150)
  ,C11          NVARCHAR(150)	--ML01
  ,C12          NVARCHAR(150)	--ML01
  ,AddDate	    DATETIME	--ML01
  ,ExtOrdKey	 NVARCHAR(50)	--ML01
  ,CtnNo			 INT	--ML01	
  ,RecGrp	    INT	--ML01
)
   INSERT INTO #DELNOTE43RDT (Orderkey,C_Company,C_Addresses,Contact2,labelno,C01,C02
                             ,C03,SKU,SDESCR,C04,C05,Qty,C06,C07,C08,C09,C10,C11,C12,AddDate,ExtOrdKey,CtnNo,RecGrp)	--ML01
   SELECT OH.Orderkey AS Orderkey
        , CASE WHEN OH.userdefine10 = 'B1' THEN OH.C_Contact1 ELSE OH.C_Company END AS C_Company
        , LTRIM(RTRIM(ISNULL(OH.C_Address1,''))) AS C_Addresses
        , LTRIM(RTRIM(ISNULL(OH.C_Contact2,''))) AS Contact2
        ,  PAD.labelno AS labelno
        , C01=ISNULL(MAX(CASE WHEN CL.Code ='C01' THEN RTRIM(CL.long) ELSE '' END),'')
        , C02=ISNULL(MAX(CASE WHEN CL.Code ='C02' THEN RTRIM(CL.long) ELSE '' END),'')
        , C03=ISNULL(MAX(CASE WHEN CL.Code ='C03' THEN RTRIM(CL.long) ELSE '' END),'')
        , PAD.SKU
        , ISNULL(s.descr,'') AS SDESCR
        , C04=ISNULL(MAX(CASE WHEN CL.Code ='C04' THEN RTRIM(CL.long) ELSE '' END),'')
        , C05=ISNULL(MAX(CASE WHEN CL.Code ='C05' THEN RTRIM(CL.long) ELSE '' END),'')
        , PAD.Qty AS Qty
        , C06=ISNULL(MAX(CASE WHEN CL.Code ='C06' THEN RTRIM(CL.long) ELSE '' END),'')
        , C07=ISNULL(MAX(CASE WHEN CL.Code ='C07' THEN RTRIM(CL.long) ELSE '' END),'')
        , C08=ISNULL(MAX(CASE WHEN CL.Code ='C08' THEN RTRIM(CL.long) ELSE '' END),'')
        , C09=ISNULL(MAX(CASE WHEN CL.Code ='C09' THEN RTRIM(CL.long) ELSE '' END),'')
        , C10=ISNULL(MAX(CASE WHEN CL.Code ='C10' THEN RTRIM(CL.long) ELSE '' END),'')
		  , C11=ISNULL(MAX(CASE WHEN CL.Code ='C11' THEN RTRIM(CL.long) ELSE '' END),'')	--ML01
		  , C12=ISNULL(MAX(CASE WHEN CL.Code ='C12' THEN RTRIM(CL.long) ELSE '' END),'')	--ML01
		  , CONVERT(DATE,PH.ADDDATE,102) AS AddDate	--ML01
		  , OH.ExternOrderKey	--ML01	--ML01
		  , PAD.CartonNo	--ML01
		  , (ROW_NUMBER() OVER (PARTITION BY OH.Orderkey ORDER BY PAD.Sku ASC)-1)/@n_NoOfLine AS RecGrp	--ML01
   FROM ORDERS OH (NOLOCK)
  -- JOIN STORER St (NOLOCK) ON St.Storerkey = OH.StorerKey
   --JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
  -- JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = OH.OrderKey AND PD.SKU = OD.SKU AND PD.OrderLineNumber = OD.OrderLineNumber
   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.orderkey = OH.Orderkey
   JOIN PACKDETAIL PAD WITH (NOLOCK) ON PAD.Pickslipno = PH.Pickslipno
   JOIN SKU S WITH (NOLOCK) ON S.storerkey = PAD.Storerkey AND S.sku = PAD.sku
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON ( CL.ListName= 'DNOTECONST' AND CL.Storerkey = OH.Storerkey )
   WHERE OH.OrderKey = @c_Orderkey
   AND PAD.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo
   GROUP BY OH.Orderkey
          , CASE WHEN OH.userdefine10 = 'B1' THEN OH.C_Contact1 ELSE OH.C_Company END
          , LTRIM(RTRIM(ISNULL(OH.C_Address1,'')))
          , LTRIM(RTRIM(ISNULL(OH.C_Contact2,'')))
          , PAD.SKU
          , ISNULL(s.descr,'')
          , PAD.labelno
          , PAD.Qty
			 , PH.ADDDATE	--ML01
			 , OH.ExternOrderKey	--ML01 
		    , PAD.CartonNo	--ML01

   SET @n_MaxRec = 0

   SELECT @n_MaxRec = COUNT(1)
   FROM  #DELNOTE43RDT
   WHERE Orderkey = @c_Orderkey

   WHILE @n_MaxRec > 0 AND @n_MaxRec< @n_MaxLineno
   BEGIN
         INSERT INTO #DELNOTE43RDT (Orderkey,C_Company,C_Addresses,Contact2,labelno,C01,C02
                             ,C03,SKU,SDESCR,C04,C05,Qty,C06,C07,C08,C09,C10,C11,C12,AddDate,ExtOrdKey,CtnNo,RecGrp)	--ML01
         SELECT TOP 1 Orderkey,'','','',labelno,'',''
                             ,'','','','','','','','','','',C10,C11,C12,AddDate,ExtOrdKey,CtnNo,RecGrp	--ML01
         FROM   #DELNOTE43RDT
         ORDER BY RowNo

         SET @n_MaxLineno = @n_MaxLineno - 1
   END


   SELECT Orderkey,C_Company,C_Addresses,Contact2,labelno,C01,C02
                             ,C03,SKU,SDESCR,C04,C05,Qty,C06,C07,C08,C09,C10,C11,C12,AddDate,ExtOrdKey,CtnNo,RecGrp	--ML01
   FROM #DELNOTE43RDT
   ORDER BY RowNo

QUIT_SP:
  DROP TABLE #DELNOTE43RDT

   IF @n_Continue = 3
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

END -- procedure

GO