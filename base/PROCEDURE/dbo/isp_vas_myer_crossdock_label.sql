SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_VAS_myer_crossdock_Label                       */
/* Creation Date: 10-MAY-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-21981 -WMS_21981_AU_Levis_VAS Myer Cross-dock label     */
/*                                                                      */
/* Called By: RDT                                                       */
/*          : Datawindow - r_dw_VAS_myer_crossdock_Label                */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 23-MAR-2022  CHONGCS  1.0  DevOps Combine Script                     */
/* 14-SEP-2023  CHONGCS  1.1  WMS-23220 revised field logic (CS01)      */
/************************************************************************/
CREATE    PROC [dbo].[isp_VAS_myer_crossdock_Label] (
      @c_LabelNo     NVARCHAR(20)

)
AS

BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt          INT
         , @n_Continue           INT = 1
         , @b_Success            INT
         , @n_Err                INT
         , @c_Errmsg             NVARCHAR(255)

 DECLARE @n_ctnsku     INT = 0
        ,@c_sdescr     NVARCHAR(60)
        ,@n_SeqNo      INT
        ,@n_GetSeqNo   INT
        ,@c_ColValue   NVARCHAR(500)
        ,@c_L08        NVARCHAR(10)
        ,@c_L16        NVARCHAR(10)
        ,@c_L09        NVARCHAR(10)
        ,@c_Notes      NVARCHAR(4000)  = ''
        ,@n_Count      INT
        ,@c_MState     NVARCHAR(45) = ''    --CS01

      CREATE TABLE #TMP_VASCD (
                              Storerkey         NVARCHAR(20)
                            , Labelno           NVARCHAR(20)
                            , ExtOrdkey         NVARCHAR(50)
                            , OHTrackingno      NVARCHAR(40)
                            , CTTrackingno      NVARCHAR(40)
                            , Shipperkey        NVARCHAR(15)
                            , BuyerPO           NVARCHAR(40)
                            , Notes             NVARCHAR(4000)
                            , CCompany          NVARCHAR(200)
                            , CAddress          NVARCHAR(250)
                            , CZip              NVARCHAR(45)
                            , MCompany          NVARCHAR(200)
                            , MAddress          NVARCHAR(250)
                            , STAddress         NVARCHAR(250)
                            , Sdescr            NVARCHAR(60)  NULL
                            , CountryBarcode    NVARCHAR(50)  NULL
                            , TrackingBarcode   NVARCHAR(50)  NULL
                            , L08               NVARCHAR(10)   NULL
                            , L16               NVARCHAR(10)   NULL
                            , L09               NVARCHAR(10)   NULL
                            , CountryBarcodehr  NVARCHAR(50)  NULL    
                            , TrackingBarcodehr NVARCHAR(50)  NULL   
                            , OHUDF07           NVARCHAR(4)   NULL
                            , Lbltitle          NVARCHAR(20)  NULL
                            , STCompany         NVARCHAR(45)  NULL
                            , STAddress1        NVARCHAR(45)  NULL
                            , LOTTVALUE         NVARCHAR(60)  NULL
                            , CCity             NVARCHAR(45) NULL  
                            , CStateZipCo       NVARCHAR(200) NULL
                           )

   --Initializing Data
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN

      SELECT @n_ctnsku = COUNT(PD.sku)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.LabelNo = @c_labelno


  --SELECT @n_ctnsku 'countsku'

      IF @n_ctnsku=1
      BEGIN
          SELECT @c_sdescr = ISNULL(S.descr,'')
          FROM PackDetail PD WITH (NOLOCK)
          JOIN SKU S WITH (NOLOCK) ON s.StorerKey=PD.StorerKey AND S.sku = PD.SKU
          WHERE PD.LabelNo = @c_labelno

      END
      ELSE
      BEGIN
          SET @c_sdescr ='MIXED'
      END

      --CS01 S
      
          SELECT DISTINCT TOP 1 @c_MState = CASE WHEN OH.C_Country = 'AU' OR OH.C_ISOcntrycode  = 'AU' THEN CASE  WHEN OH.M_zip LIKE '3%' THEN 'VIC'  
                                                                                                         WHEN OH.M_zip LIKE '4%' THEN 'QLD'  
                                                                                                         WHEN OH.M_zip LIKE '5%' THEN 'SA'  
                                                                                                         WHEN OH.M_zip LIKE '0%' THEN 'NT'  
                                                                                                         WHEN OH.M_zip LIKE '6%' THEN 'WA'  
                                                                                                         WHEN OH.M_zip LIKE '7%' THEN 'TAS'  
                                                                                                         WHEN ((OH.M_zip >= '2600' AND OH.M_zip <= '2618')   
                                                                                                            OR (OH.M_zip >= '2900' AND OH.M_zip <= '2920')) THEN 'ACT'  
                                                                                                         ELSE 'NSW'   
                                                                                                   END  
                                           WHEN OH.C_Country = 'NZ' OR OH.C_ISOcntrycode  = 'NZ' THEN CASE WHEN LEFT(TRIM(ISNULL(OH.M_zip,'')),1) IN ('7','8','9') THEN 'SI'  
                                                                                                                                                               ELSE 'NI'  
                                                                                                                                                               END  
                                                     END  

           FROM packdetail pd (nolock)
           JOIN cartontrack ct (nolock) on pd.labelno = ct.labelno
           JOIN orders oh (nolock) on oh.TrackingNo = ct.udf03
           JOIN orderdetail od (nolock) on oh.orderkey = od.orderkey
          JOIN Storer ST (NOLOCK) ON ST.StorerKey=Oh.StorerKey
           where PD.LabelNo = @c_LabelNo

      --CS01 E

      INSERT INTO #TMP_VASCD
                              (
                                  Storerkey,
                                  Labelno,
                                  ExtOrdkey,
                                  OHTrackingno,
                                  CTTrackingno,
                                  Shipperkey,
                                  BuyerPO,
                                  CCompany,
                                  CAddress,
                                  CZip,
                                  MCompany,
                                  MAddress,
                                  STAddress,
                                  Notes,
                                  Sdescr,
                                  CountryBarcode,
                                  TrackingBarcode,
                                  L08,
                                  L16,
                                  L09,
                                  CountryBarcodehr,TrackingBarcodehr,
                                  OHUDF07,Lbltitle,STCompany,STAddress1,
                                  LOTTVALUE,CCity,CStateZipCo
                              )

    SELECT DISTINCT TOP 1 O.StorerKey,PD.LabelNo,
           O.externorderkey,
           O.TrackingNo,'',
           O.ShipperKey,O.BuyerPO,
           SUBSTRING(O.C_Company,1,15),
            RTRIM(ISNULL(o.C_Address1,'')) + ','  ,
           ISNULL(o.C_zip,''),SUBSTRING(ISNULL(o.M_Company,''),1,15),
            RTRIM(ISNULL(o.M_Address1,'')) + SPACE(1) +  RTRIM(ISNULL(o.M_City,'')) + ',' +  @c_MState + ',' +  RTRIM(ISNULL(o.M_Zip,'')),    --CS01
           ISNULL(ST.City,'') + ',' + ISNULL(ST.State,'')+ ',' + ISNULL(ST.zip,'')+ ',' + ISNULL(ST.Country,''),
           od.Notes ,@c_sdescr,'(421)'+ '036'+ ISNULL(o.C_zip,'')+'(90)'+ concat (0, o.userdefine05),
           '(00)'+SUBSTRING(LOTTABLEVALUE, 3, LEN(LOTTABLEVALUE) - 2),--'('+LEFT(ct.TrackingNo,2)+')'+RIGHT(ct.TrackingNo,LEN(ct.TrackingNo)-2),   
            concat (0, o.userdefine05) ,concat (0, o.userdefine04) ,LEFT(o.UserDefine01,4),N'Ê421036'+ ISNULL(o.C_zip,'')+N'Ê90'+ concat (0, RTRIM(o.userdefine05)),
         N'Ê00' +SUBSTRING(LOTTABLEVALUE, 3, LEN(LOTTABLEVALUE) - 2),
         FORMAT(o.USERDEFINE07,'ddMM'),'AD' ,ISNULL(ST.Company,''),ISNULL(ST.Address1,''),RTRIM(Pd.LOTTABLEVALUE),RTRIM(ISNULL(o.C_City,'')),
          RTRIM(ISNULL(o.c_state,'')) + ',' +  RTRIM(ISNULL(o.C_zip,'')) + ',' +  RTRIM(ISNULL(o.C_Country,''))
  FROM packdetail pd (nolock)
  JOIN cartontrack ct (nolock) on pd.labelno = ct.labelno
  JOIN orders o (nolock) on o.TrackingNo = ct.udf03
  JOIN orderdetail od (nolock) on o.orderkey = od.orderkey
 JOIN Storer ST (NOLOCK) ON ST.StorerKey=O.StorerKey
  where PD.LabelNo = @c_labelno

   END

   --Output Result back to DW
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT *
      FROM #TMP_VASCD
   END

   --Clean up - Drop Temp table & Close, Deallocate Cursor

   IF CURSOR_STATUS('LOCAL', 'CUR_SPLIT') IN (0 , 1)
   BEGIN
      CLOSE CUR_SPLIT
      DEALLOCATE CUR_SPLIT
   END
END

GO