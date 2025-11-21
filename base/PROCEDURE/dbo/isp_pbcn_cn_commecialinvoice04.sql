SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_PBCN_CN_CommecialInvoice04                     */
/* Creation Date: 18-JUN-2019                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-9400 - [CN] Boardriders - CCI Report And Trigger Point  */
/*                                                                      */
/*                                                                      */
/* Called By: report dw = r_dw_cn_commercialinvoice_04                  */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 23-Feb-2021  LZG       1.1   INC1434916 - JOIN PickDetail (ZG01)     */
/* 25-Feb-2021  ALiang    1.2   Bug Fix                                 */    
/************************************************************************/

CREATE PROC [dbo].[isp_PBCN_CN_CommecialInvoice04] (
  @cMBOLKey NVARCHAR(21)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE  @n_rowid          INT,
            @c_cartontype     NVARCHAR(10),
            @c_prevcartontype NVARCHAR(10),
            @n_cnt            INT

   DECLARE  @c_getmbolkey NVARCHAR(20),
            @c_CCompany   NVARCHAR(45),
            @c_CAdd1      NVARCHAR(45),
            @c_CAdd2      NVARCHAR(45),
            @c_CAdd3      NVARCHAR(45),

            @c_FDESCR     NVARCHAR(120),
            @c_FAdd1      NVARCHAR(45),
            @c_FAdd2      NVARCHAR(45),
            @c_FPhone1    NVARCHAR(18),

            @c_Storerkey  NVARCHAR(20),
            @c_BookingRef NVARCHAR(30),
            @c_ExtOrdkey  NVARCHAR(20),
            @d_MDepDate   DATETIME,
            @n_MUDF01     FLOAT,

            @n_MUDF02     FLOAT,
            @n_MUDF03     FLOAT ,
            @n_MUDF04     FLOAT,
            @n_MUDF05     FLOAT,
            @c_shipterm   NVARCHAR(120)

   DECLARE  @d_MArrDate   DATETIME ,
            @c_FPhone2    NVARCHAR(18),
            @c_Fcontact1  NVARCHAR(45),
            @c_Femail1    NVARCHAR(60),
            @c_Femail2    NVARCHAR(60),

            @c_Fcontact2  NVARCHAR(45),
            @c_Fcity      NVARCHAR(45),
            @c_FFacility  NVARCHAR(10),
            @c_Incoterm   NVARCHAR(10),
            @d_MEditdate  DATETIME,

            @c_MPOFDELIVERY    NVARCHAR(45) ,
            @c_Orderkey        NVARCHAR(20) ,
            @c_SEA             NVARCHAR(120),
            @c_SKU             NVARCHAR(20),
            @c_SDESCR          NVARCHAR(60),

            @c_SSTYLE          NVARCHAR(20),
            @n_StdGrosswgt     FLOAT,
            @c_LOTT02          NVARCHAR(30),
            @c_LOTT03          NVARCHAR(30),
            @c_LOTT08          NVARCHAR(30),
            @c_POSellerName    NVARCHAR(45),

            @c_SellerAdd1       NVARCHAR(45),
            @c_SellerAdd2       NVARCHAR(45),
            @c_SellerCity       NVARCHAR(45),
            @c_SellerOriCountry NVARCHAR(45),
            @c_PODUDF04         NVARCHAR(30),

            @n_PODUDF09         INT,
            @n_UnitPrice        FLOAT,
            @n_PQty             INT,
            @n_TTLCNTS          INT,
            @c_POKEY            NVARCHAR(20),
            @n_GTTTLCNTS        INT,
            @n_GTPQTY           INT,
            @n_TTLQtyUnitPrice  Decimal(10,2),
            @n_GTQtyUnitPrice   Decimal(10,2),
            @n_VATAMOUNT        Decimal(10,2),
            @c_TTLCTNINWORDS    NVARCHAR(500),
            @c_TTLQTYINWORDS    NVARCHAR(500),
            @c_VATAMTINWORDS NVARCHAR(500),
            @c_GTTLAMTINWORDS   NVARCHAR(500)

   CREATE TABLE #TMP_MBOLORD04 (
         rowid           INT NOT NULL identity(1,1) PRIMARY KEY,
         c_Company       NVARCHAR(45) NULL,
         C_Address1      NVARCHAR(45) NULL,
         C_Address2      NVARCHAR(45) NULL,
         C_Address3      NVARCHAR(45) NULL,
         FDESCR          NVARCHAR(120) NULL,
         F_Address1      NVARCHAR(45) NULL,
         F_Address2      NVARCHAR(45) NULL,
         MBOLKey         NVARCHAR(20) NULL,
         FPhone1         NVARCHAR(18) NULL,
         Storerkey       NVARCHAR(20) NULL,
         BookingRef      NVARCHAR(30) NULL,
         ExtOrdkey       NVARCHAR(20) NULL,
         MDepartureDate  DATETIME NULL,
         MUDF01          NVARCHAR(30) NULL,
         MUDF02          NVARCHAR(30) NULL,
         MUDF03          NVARCHAR(30) NULL,
         MUDF04          NVARCHAR(30) NULL,
         MUDF05          NVARCHAR(30) NULL,
         shipterm        NVARCHAR(120) NULL,
         MArrivalDate    DATETIME NULL,
         FPhone2         NVARCHAR(18) NULL,
         Fcontact1       NVARCHAR(45) NULL,
         Femail1         NVARCHAR(60) NULL,
         Fcontact2       NVARCHAR(45) NULL,
         Femail2         NVARCHAR(60) NULL,
         Fcity           NVARCHAR(45) NULL,
         FFacility       NVARCHAR(10) NULL,
         Incoterm        NVARCHAR(10) NULL,
         MEditdate       DATETIME NULL,
         MPOFDELIVERY    NVARCHAR(45) NULL,
         Orderkey        NVARCHAR(20) NULL,
         SEA             NVARCHAR(120) NULL,
         SKU             NVARCHAR(20) NULL,
         SDESCR          NVARCHAR(120) NULL,
         SSTYLE          NVARCHAR(50) NULL,
         StdGrosswgt     FLOAT,
         TTLCNTS         INT
        )

   CREATE TABLE #TMP_CNINV04 (
         -- rowid           INT NOT NULL identity(1,1) PRIMARY KEY,
         c_Company       NVARCHAR(60) NULL,
         C_Address1      NVARCHAR(60) NULL,
         C_Address2      NVARCHAR(60) NULL,
         C_Address3      NVARCHAR(60) NULL,
         FDESCR          NVARCHAR(120) NULL,
         F_Address1      NVARCHAR(45) NULL,
         F_Address2      NVARCHAR(45) NULL,
         MBOLKey         NVARCHAR(20) NULL,
         FPhone1         NVARCHAR(18) NULL,
         Storerkey       NVARCHAR(20) NULL,
         SKU             NVARCHAR(20) NULL,
         Descr           NVARCHAR(120) NULL,
         SSTyle          NVARCHAR(20) NULL,
         BookingRef      NVARCHAR(30) NULL,
         Lottable03      NVARCHAR(30) NULL,
         Lottable08      NVARCHAR(30) NULL,
         StdGrossWgt     FLOAT,
         PQTY            INT,
         ExtOrdkey       NVARCHAR(20) NULL,
         MUDF01          NVARCHAR(20) NULL,
         MUDF02          NVARCHAR(20) NULL,
         MUDF03          NVARCHAR(20) NULL,
         MUDF04          NVARCHAR(20) NULL,
         MUDF05          NVARCHAR(20) NULL,
         PTTLCTN         INT,
         shipterm        NVARCHAR(120) NULL,
         MDepartureDate  DATETIME NULL,
         MArrivalDate    DATETIME NULL,
         SellerName      NVARCHAR(45) NULL,
         POSellerAdd1    NVARCHAR(45) NULL,
         POSellerAdd2    NVARCHAR(45) NULL,
         UnitPrice       FLOAT,
         POSellerCity    NVARCHAR(45) NULL,
         POOriginCountry NVARCHAR(45) NULL,
         PDUDF04         NVARCHAR(30) NULL,
         PDUDF09         INT NULL,
         FPhone2         NVARCHAR(18) NULL,
         Fcontact1       NVARCHAR(45) NULL,
         Femail1         NVARCHAR(60) NULL,
         Fcontact2       NVARCHAR(45) NULL,
         Femail2         NVARCHAR(60) NULL,
         Fcity           NVARCHAR(45) NULL,
         FFacility       NVARCHAR(10) NULL,
         Incoterm        NVARCHAR(10) NULL,
         MEditdate       DATETIME NULL,
         MPOFDELIVERY    NVARCHAR(45) NULL,
         SEA             NVARCHAR(120) NULL,
         GTTTLCNTS       INT NULL,
         GTPQTY          INT NULL,
         VATAMT          FLOAT,
         GTQtyUnitPrice  FLOAT,
         GTTLAMT         FLOAT,
         TTLCTNINWORDS   NVARCHAR(500) NULL,
         TTLQTYINWORDS   NVARCHAR(500) NULL,
         VATAMTINWORDS   NVARCHAR(500) NULL,
         GTTLAMTINWORDS  NVARCHAR(500) NULL
        )

   INSERT INTO #TMP_MBOLORD04 (c_Company,C_Address1,C_Address2,C_Address3,FDESCR,F_Address1,F_Address2,MBOLKey,
                              FPhone1,Storerkey,BookingRef,ExtOrdkey,MDepartureDate,MUDF01,MUDF02,MUDF03,MUDF04,
                              MUDF05,shipterm,MArrivalDate,FPhone2,Fcontact1,Femail1,Fcontact2,Femail2,Fcity,FFacility,
                              Incoterm,MEditdate,MPOFDELIVERY,Orderkey,SEA,SKU,SDESCR,SSTYLE,StdGrosswgt,TTLCNTS
         )
   SELECT DISTINCT
         --ORDERS.c_Company AS c_Company,
         --ORDERS.c_Address1 AS C_Address1,
         --ORDERS.c_Address2 AS C_Address2,
         --ORDERS.c_Address3 AS C_Address3,
         ISNULL(C2.UDF01,'') ,
         ISNULL(C2.UDF02,'') ,
         ISNULL(C2.UDF03,'') ,
         ISNULL(C2.UDF04,'') ,
         F.Descr AS FDESCR,
         F.Address1 AS F_Address1,
         F.Address2 AS F_Address2,
         MBOL.MBOLKey AS MBOLKey,
         F.Phone1 AS FPhone1,
         ORDERS.StorerKey AS Storerkey,
         Container.BookingReference AS BookingRef,
         ORDERS.ExternOrderkey AS ExtOrdkey,
         MBOL.DepartureDate AS MDepartureDate ,
         CASE WHEN ISNUMERIC(MBOL.UserDefine01) = 1 THEN CAST(ISNULL(MBOL.UserDefine01,'') as Decimal(6,2)) ELSE 0.00 END AS MUDF01,
         CASE WHEN ISNUMERIC(MBOL.UserDefine02) = 1 THEN CAST(ISNULL(MBOL.UserDefine02,'') as Decimal(6,2)) ELSE 0.00 END AS MUDF02,
         CASE WHEN ISNUMERIC(MBOL.UserDefine03) = 1 THEN CAST(ISNULL(MBOL.UserDefine03,'') as Decimal(6,2)) ELSE 0.00 END AS MUDF03,
         CASE WHEN ISNUMERIC(MBOL.UserDefine04) = 1 THEN CAST(ISNULL(MBOL.UserDefine04,'') as Decimal(6,2)) ELSE 0.00 END AS MUDF04,
         CASE WHEN ISNUMERIC(MBOL.UserDefine05) = 1 THEN CAST(ISNULL(MBOL.UserDefine05,'') as Decimal(6,2)) ELSE 0.00 END AS MUDF05,
         ISNULL(C1.Notes,'') AS shipterm,
         MBOL.ArrivalDate  AS MArrivalDate,
         F.Phone2 AS FPhone2
         ,F.contact1 AS Fcontact1
         ,F.email1 AS Femail1
         ,F.contact2 AS Fcontact2
         ,F.email2 AS Femail2
         ,F.city AS Fcity
         ,F.Facility AS FFacility
         ,ORDERS.Incoterm
         ,MBOL.editdate
         ,MBOL.PlaceOfDischarge
         , ORDERS.Orderkey
         ,ISNULL(C.long,'') as SEA
         ,OD.SKU,S.descr,(ISNULL(s.style,'') + '-' +ISNULL(s.color,'')) as SSTYLE
         ,s.stdgrosswgt,PH.TTLCNTS
         FROM MBOL WITH (NOLOCK)
         JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
         JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
         --JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = ORDERS.Orderkey   -- ZG01
         JOIN PICKDETAIL OD WITH (NOLOCK) ON OD.Orderkey = ORDERS.Orderkey      -- ZG01
         JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORDERS.Orderkey
         JOIN FACILITY F WITH (NOLOCK) ON F.Facility = MBOL.Facility
         JOIN STORER ST WITH (NOLOCK) ON (ORDERS.Storerkey = ST.Storerkey)
         JOIN Container WITH (NOLOCK) ON (Container.MBOLKey = Mbol.MBOLKey)
         JOIN SKU S WITH (NOLOCK) ON S.StorerKey=OD.StorerKey and S.Sku=OD.Sku
         LEFT JOIN CODELKUP C WITH (NOLOCK) ON c.listname='TRANSMETH' AND c.code=MBOL.TransMethod AND c.Storerkey=ORDERS.StorerKey
         LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON c1.listname='BRCNFAC' AND c1.short=MBOL.Facility AND c1.Storerkey=ORDERS.StorerKey
         LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON c2.listname='BRregion' AND c2.code=ORDERS.UserDefine10 AND c2.Storerkey=ORDERS.StorerKey
   WHERE MBOL.MBOLKey = @cMBOLKey
   GROUP BY ISNULL(C2.UDF01,'') ,
            ISNULL(C2.UDF02,'') ,
            ISNULL(C2.UDF03,'') ,
            ISNULL(C2.UDF04,'') ,
            --ORDERS.c_Company,ORDERS.c_Address1,ORDERS.c_Address2,ORDERS.c_Address3,
            F.Descr,F.Address1,F.Address2,F.Phone1,F.Phone2,
            F.contact1,F.email1 ,F.contact2,F.email2 ,F.city ,ORDERS.Incoterm ,MBOL.editdate,MBOL.PlaceOfDischarge,ISNULL(C.long,''),
            F.Facility,CASE WHEN ISNUMERIC(MBOL.UserDefine01) = 1 THEN CAST(ISNULL(MBOL.UserDefine01,'') as Decimal(6,2)) ELSE 0.00 END,
            CASE WHEN ISNUMERIC(MBOL.UserDefine02) = 1 THEN CAST(ISNULL(MBOL.UserDefine02,'') as Decimal(6,2)) ELSE 0.00 END,
            CASE WHEN ISNUMERIC(MBOL.UserDefine03) = 1 THEN CAST(ISNULL(MBOL.UserDefine03,'') as Decimal(6,2)) ELSE 0.00 END,
            CASE WHEN ISNUMERIC(MBOL.UserDefine04) = 1 THEN CAST(ISNULL(MBOL.UserDefine04,'') as Decimal(6,2)) ELSE 0.00 END,
            CASE WHEN ISNUMERIC(MBOL.UserDefine05) = 1 THEN CAST(ISNULL(MBOL.UserDefine05,'') as Decimal(6,2)) ELSE 0.00 END,
            MBOL.DepartureDate,MBOL.ArrivalDate,ISNULL(C1.Notes,''),Container.BookingReference,
            ORDERS.ExternOrderkey,MBOL.MBOLKey ,ORDERS.StorerKey,ORDERS.Orderkey,OD.SKU,S.descr,
            (ISNULL(s.style,'') + '-' +ISNULL(s.color,'')),s.stdgrosswgt,PH.TTLCNTS

   SET @n_GTTTLCNTS = 1
   SET @n_GTPQTY = 1
   SET @n_TTLQtyUnitPrice = 0.00
   SET @n_GTQtyUnitPrice = 0.00
   SET @n_VATAMOUNT = 0.00

   SELECT @n_GTTTLCNTS = SUM(PH.TTLCNTS)
   FROM MBOL WITH (NOLOCK)
   JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORDERS.Orderkey
   WHERE MBOL.MBOLKey = @cMBOLKey

   DECLARE CUR_MBOLORER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT c_Company,C_Address1,C_Address2,C_Address3,FDESCR,F_Address1,F_Address2,MBOLKey,FPhone1,Storerkey,
         BookingRef,ExtOrdkey,MDepartureDate ,MUDF01,MUDF02,MUDF03,MUDF04,MUDF05,shipterm,MArrivalDate,FPhone2,
         Fcontact1,Femail1,Fcontact2,Femail2,Fcity,FFacility,Incoterm,MEditdate,MPOFDELIVERY,Orderkey,SEA,SKU,
         SDESCR,SSTYLE,StdGrosswgt,TTLCNTS
   FROM   #TMP_MBOLORD04 MORD04
   WHERE MORD04.MBOLKey = @cMBOLKey
   ORDER BY MORD04.MBOLKey,MORD04.OrderKey,MORD04.SKU

   OPEN CUR_MBOLORER

   FETCH NEXT FROM CUR_MBOLORER INTO @c_CCompany,@c_CAdd1,@c_CAdd2,@c_CAdd3,@c_FDESCR,@c_FAdd1,@c_FAdd2,@c_getmbolkey,@c_FPhone1,
                                    @c_Storerkey,@c_BookingRef,@c_ExtOrdkey,@d_MDepDate,@n_MUDF01,@n_MUDF02,@n_MUDF03,@n_MUDF04,
                                    @n_MUDF05,@c_shipterm,@d_MArrDate,@c_FPhone2,@c_Fcontact1,@c_Femail1,@c_Fcontact2,@c_Femail2,
                                    @c_Fcity,@c_FFacility,@c_Incoterm,@d_MEditdate,@c_MPOFDELIVERY,@c_Orderkey,@c_SEA,@c_sku,
                                    @c_SDESCR,@c_SSTYLE,@n_StdGrosswgt ,@n_TTLCNTS

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_PQty             = 0
      SET @c_LOTT02           = ''
      SET @c_LOTT03           = ''
      SET @c_LOTT08           = ''
      SET @c_POKEY            = ''
      SET @c_POSellerName     = ''
      SET @c_SellerAdd1       = ''
      SET @c_SellerAdd2       = ''
      SET @c_SellerCity       = ''
      SET @c_SellerOriCountry = ''
      SET @c_PODUDF04         = ''
      SET @n_PODUDF09         = 0
      SET @n_UnitPrice        = 0

      SELECT @n_PQty = SUM(PD.qty)
      FROM PICKDETAIL PD WITH (NOLOCK)
      WHERE PD.Storerkey = @c_Storerkey
      AND PD.Orderkey = @c_Orderkey
      AND PD.SKU = @c_sku

      SELECT DISTINCT @c_LOTT02 = LOTT.lottable02
                     , @c_LOTT03 = LOTT.lottable03
                     , @c_LOTT08 = LOTT.lottable08
      FROM PICKDETAIL PD WITH (NOLOCK)
      JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.LOT = PD.Lot AND LOTT.Sku = PD.SKU AND LOTT.Storerkey = PD.Storerkey
      WHERE PD.Storerkey = @c_Storerkey
      AND PD.Orderkey = @c_Orderkey
      AND PD.SKU = @c_sku

      SELECT @c_POKEY = PO.Pokey
            ,@c_POSellerName = PO.SellerName
            ,@c_SellerAdd1 = ISNULL(PO.SellerAddress1,'')
            ,@c_SellerAdd2 = ISNULL(PO.SellerAddress2,'')
            ,@c_SellerCity = ISNULL(PO.SellerCity,'')
            ,@c_SellerOriCountry = ISNULL(PO.OriginCountry,'')
      FROM PO WITH (NOLOCK)
      WHERE PO.xdockpokey = @c_LOTT03
      AND PO.POType = @c_LOTT02
      AND PO.Storerkey = @c_Storerkey

      SELECT @n_UnitPrice = MIN(POD.UnitPrice)
            ,@c_PODUDF04 = MAX(POD.Userdefine04)
            ,@n_PODUDF09 = CASE WHEN ISNUMERIC(MAX(POD.Userdefine09)) = 1 THEN  CAST(MAX(POD.Userdefine09) AS decimal(5,0)) ELSE 0 END
      FROM PODETAIL POD WITH (NOLOCK)
      WHERE POD.Pokey = @c_POKEY
      AND POD.Storerkey = @c_Storerkey
	  AND POD.SKU= @c_sku     --AL01   								  

      IF @n_PODUDF09 = '' OR @n_PODUDF09 = '0'
      BEGIN
         SET @n_PODUDF09 = '0'
      END

      INSERT INTO #TMP_CNINV04 (c_Company,C_Address1,C_Address2,C_Address3,FDESCR,F_Address1,F_Address2,MBOLKey,FPhone1,Storerkey,
                                 SKU,Descr,SSTyle,BookingRef,PQTY,Lottable03,Lottable08,StdGrossWgt,ExtOrdkey,MDepartureDate,MUDF01,
                                 MUDF02,MUDF03,MUDF04,MUDF05,PTTLCTN,shipterm,MArrivalDate,SellerName,POSellerAdd1,POSellerAdd2,
                                 POSellerCity,UnitPrice,POOriginCountry,PDUDF04,PDUDF09,FPhone2,Fcontact1,Femail1,Fcontact2,
                                 Femail2,Fcity,FFacility,Incoterm,MEditdate,MPOFDELIVERY,SEA,GTTTLCNTS,GTPQTY,VATAMT,GTQtyUnitPrice,GTTLAMT )
      VALUES(@c_CCompany,@c_CAdd1,@c_CAdd2,@c_CAdd3,@c_FDESCR,@c_FAdd1,@c_FAdd2,@c_getmbolkey,@c_FPhone1, @c_Storerkey,
            @c_sku,@c_SDESCR,@c_SSTYLE,@c_BookingRef,@n_PQty,@c_LOTT03,@c_LOTT08,@n_StdGrosswgt,@c_ExtOrdkey,@d_MDepDate,@n_MUDF01,
            @n_MUDF02,@n_MUDF03,@n_MUDF04,@n_MUDF05,@n_TTLCNTS,@c_shipterm,@d_MArrDate,@c_POSellerName,@c_SellerAdd1,@c_SellerAdd2,
            @c_SellerCity,@n_UnitPrice,@c_SellerOriCountry,@c_PODUDF04,@n_PODUDF09,@c_FPhone2,@c_Fcontact1,@c_Femail1,@c_Fcontact2,
            @c_Femail2,@c_Fcity,@c_FFacility,@c_Incoterm,@d_MEditdate,@c_MPOFDELIVERY,@c_SEA,@n_GTTTLCNTS,0,0.00,0.00,0.00 )


      FETCH NEXT FROM CUR_MBOLORER INTO @c_CCompany,@c_CAdd1,@c_CAdd2,@c_CAdd3,@c_FDESCR,@c_FAdd1,@c_FAdd2,@c_getmbolkey,@c_FPhone1,
                                       @c_Storerkey,@c_BookingRef,@c_ExtOrdkey,@d_MDepDate,@n_MUDF01,@n_MUDF02,@n_MUDF03,@n_MUDF04,
                                       @n_MUDF05,@c_shipterm,@d_MArrDate,@c_FPhone2,@c_Fcontact1,@c_Femail1,@c_Fcontact2,@c_Femail2,
                                       @c_Fcity,@c_FFacility,@c_Incoterm,@d_MEditdate,@c_MPOFDELIVERY,@c_Orderkey,@c_SEA,@c_sku,
                                       @c_SDESCR,@c_SSTYLE,@n_StdGrosswgt ,@n_TTLCNTS
   END

   SELECT @n_GTPQTY = SUM(PQTY)
   FROM #TMP_CNINV04
   WHERE MBOLKey= @c_getmbolkey

   SELECT @n_TTLQtyUnitPrice = SUM(Pqty*UnitPrice)
   FROM #TMP_CNINV04
   WHERE MBOLKey= @c_getmbolkey

   --SET @n_VATAMOUNT =  @n_TTLQtyUnitPrice * @n_PODUDF09 -- ZG01
   SELECT @n_VATAMOUNT = SUM(PQty * UnitPrice * PDUDF09) / 100
   FROM #TMP_CNINV04
   WHERE MBOLKey = @c_getmbolkey

   SELECT @n_GTQtyUnitPrice = (@n_TTLQtyUnitPrice + MUDF01 + MUDF02 +MUDF03+ MUDF04 + MUDF05)
   FROM #TMP_CNINV04
   WHERE MBOLKey= @c_getmbolkey

   SET  @c_TTLCTNINWORDS = ''
   SET  @c_TTLQTYINWORDS = ''
   SET  @c_VATAMTINWORDS = ''
   SET  @c_GTTLAMTINWORDS = ''

   SELECT @c_TTLCTNINWORDS = '(' + (UPPER(dbo.fnc_NumberToWords(GTTTLCNTS,'','','','')) + ' CARTONS )')
         ,@c_TTLQTYINWORDS = '(' + (UPPER(dbo.fnc_NumberToWords(@n_GTPQTY,'','','','')) + ' PIECES )')
         ,@c_VATAMTINWORDS = 'Buying agent agreement to be added only on VAT base'
         ,@c_GTTLAMTINWORDS = '(' +(UPPER(dbo.fnc_NumberToWords(@n_GTQtyUnitPrice,'','','Cents',' IN USD )')))
   FROM #TMP_CNINV04
   WHERE MBOLKey= @c_getmbolkey

   UPDATE #TMP_CNINV04
   SET GTPQTY         = @n_GTPQTY
      ,VATAMT         = @n_VATAMOUNT
      ,GTQtyUnitPrice = @n_TTLQtyUnitPrice
      ,GTTLAMT        = @n_GTQtyUnitPrice
      ,TTLCTNINWORDS  = @c_TTLCTNINWORDS
      ,TTLQTYINWORDS  = @c_TTLQTYINWORDS
      ,VATAMTINWORDS  = @c_VATAMTINWORDS
      ,GTTLAMTINWORDS = @c_GTTLAMTINWORDS
   WHERE MBOLKey= @c_getmbolkey

   SELECT *
   FROM #TMP_CNINV04
END

GO