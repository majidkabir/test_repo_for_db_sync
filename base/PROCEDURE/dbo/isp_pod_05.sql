SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_pod_05                                         */
/* Creation Date:19-Aug-2016                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: POD                                                         */
/*                                                                      */
/* Called By: r_dw_pod_05  SOS#375550(copy from r_dw_pod_03             */ 
/*                                                                      */
/* Parameters: (Input)  @c_mbolkey   = MBOL No                          */
/*                      @c_exparrivaldate = Expected arrival date       */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 20Jul2010    GTGOH     1.1  SOS#180015 - Insert POD Barcode for      */
/*                             Codelkup.Listname='STRDOMAIN' (GOH01)    */
/*  28-Jul-2011 YTWan     1.2  S#221722 (Wan01)                         */
/*                             - 1. Notes shows unreadable character    */
/*                             - 2. IF Storer.SUSR3<>1,                 */
/*                                  Orders.Consigneekey=Storer.Storerkey*/                      
/*                                  IF Storer.SUSR3=1,Orders.billtokey+ */
/*                                  Orders.Consigneekey=Storer.Storerkey*/ 
/*  11-Nov-2011 YTWan     1.3  SOS#229724.Get data from orders if storer*/
/*                             no record.(Wan02)                        */
/*  12-Jan-2012 YTWan     1.3  New formula to calc delviery date.(wan03)*/
/*  11-Oct-2013 YTWan     1.4  SOS#291810 - VFCDC MBOLPOD.(Wan04)       */
/*  06-Dec-2013 YTWan     1.5  SOS#297136- VF POD - Add Brand.(Wan05)   */
/*  17-Dec-2013 YTWan     1.6  SOS#297903- Revise Cube calc (Wan06)     */
/*  23-Jan-2014 YTWan     1.7  SOS#301258- VFCDC - Revise logic to      */
/*                             calculate carton qty in POD.(Wan07)      */
/*  07-MAR-2014 YTWan     1.8  SOS#304848 - VFCDC - Add validation for  */
/*                             printing POD. (Wan08)                    */
/*  06-AUG-2014 YTWan     1.9  SOS#317440 - TBL MG - Revise POD for Xdock*/
/*                             (Wan09)                                  */
/*  01-OCT-2015 NJOW01    2.0  352874-change retrieve condition for     */
/*                             address and barcode.                     */
/* 12-Apr-2016 CSCHONG    2.1  367692 - Show store code (CS01)          */
/* 19-Aug-2016 CSCHONG    2.2  375550 - New field (CS02)                */
/* 15-Dec-2018  TLTING01  2.3   Missing nolock                          */
/* 28-Jan-2019  TLTING_ext 2.4  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_pod_05]
        @c_mbolkey NVARCHAR(10), 
        @c_exparrivaldate  NVARCHAR(30) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_orderkey NVARCHAR(10),
           @c_type     NVARCHAR(10),
           @n_casecnt  int,
           @n_qty      int,
           @n_totalcasecnt int,
           @n_totalqty     int

   DECLARE @n_TotalWeight  FLOAT                                                                   --(Wan01)
         , @n_TotalCube    FLOAT                                                                   --(Wan01)

         , @n_Weight       FLOAT                                                                   --(Wan04)
         , @n_Cube         FLOAT                                                                   --(Wan04)
         , @n_SetMBOLAsOrd          INT                                                            --(Wan04)
         , @n_OrderShipAddress      INT                                                            --(Wan04)
         , @n_WgtCubeFromPackInfo   INT                                                            --(Wan04)
         , @n_CountCntByLabelno     INT                                                            --(Wan07) 
         , @c_Storerkey             NVARCHAR(15)                                                   --(Wan04)

         , @c_Brand                 NVARCHAR(20)                                                   --(Wan05)
         
         , @n_PrintAfterPacked      INT                                                            --(Wan08)
         , @c_printdate             NVARCHAR(30)                                                   --(Wan08) 
         , @c_printby               NVARCHAR(30)                                                   --(Wan08)   
			, @c_showfield             NVARCHAR(1)                                                    --(CS01)  
			, @n_TTLCnt                INT                                                            --(CS02)

   SET @n_Weight              = 0.00                                                               --(Wan04)
   SET @n_Cube                = 0.00                                                               --(Wan04)
   SET @n_SetMBOLAsOrd        = 0                                                                  --(Wan04)
   SET @n_OrderShipAddress    = 0                                                                  --(Wan04)
   SET @n_WgtCubeFromPackInfo = 0                                                                  --(Wan04)
   SET @n_CountCntByLabelno   = 0                                                                  --(Wan07)
   SET @c_Storerkey           = ''                                                                 --(Wan04)

   SET @c_Brand               = ''                                                                 --(Wan05)

   SET @n_PrintAfterPacked    = 0                                                                  --(Wan08)
   SET @c_printdate           = REPLACE(CONVERT(NVARCHAR(20),GETDATE(),120),'-','/')               --(Wan08) 
   SET @c_printby             = SUSER_NAME()                                                       --(Wan08)   
   SET @n_TTLCnt              = 0                                                                  --(CS02)                                                               

   CREATE TABLE #POD
   (mbolkey           NVARCHAR(10) null,
    MbolLineNumber    NVARCHAR(5)  null,
    ExternOrderKey    NVARCHAR(50) null,   --tlting_ext
    Orderkey          NVARCHAR(10) null,
    Type              NVARCHAR(10) null,
    EditDate          datetime null,
    Company           NVARCHAR(45)  null,
--    C_Contact         NVARCHAR(60)  null,
--    C_Address         NVARCHAR(180) null,
--    C_Phone           NVARCHAR(36)  null,
    CaseCnt           int       null,
    Qty               int        null,
    TotalCaseCnt      int       null,
    TotalQty          int        null,
--    Address         NVARCHAR(180) null,
--    Phone           NVARCHAR(36)  null,
--    Fax             NVARCHAR(36)  null,
--    Contact         NVARCHAR(60)  null,
    leadtime        int null,
    logo NVARCHAR(60) null,
    B_Address1 NVARCHAR(45) null,
    B_Contact1 NVARCHAR(30) null,
    B_Phone1 NVARCHAR(18) null,
    B_Fax1 NVARCHAR(18) null,
    Susr2 NVARCHAR(20) null,
    MbolLoadkey NVARCHAR(10) null,
    shipto NVARCHAR(65) null,
    shiptoadd1 NVARCHAR(45) null,
    shiptoadd2 NVARCHAR(45) null,
    shiptoadd3 NVARCHAR(45) null,
    shiptoadd4 NVARCHAR(45) null,
    shiptocity NVARCHAR(45) null,
    shiptocontact1 NVARCHAR(30) null,
    shiptocontact2 NVARCHAR(30) null,
    shiptophone1 NVARCHAR(18) null,
    shiptophone2 NVARCHAR(18) null,
    --(Wan01) - START
    --note1a NVARCHAR(215) null,
    --note1b NVARCHAR(215) null,
    --note2a NVARCHAR(215) null,
    --note2b NVARCHAR(215) null,
    --note1a NVARCHAR(215) null,
    note1a NVARCHAR(216) null,
    note1b NVARCHAR(214) null,
    note2a NVARCHAR(216) null,
    note2b NVARCHAR(214) null,
    --(Wan01) - END
    --(Wan01) - START
    Weight        FLOAT NULL,
    Cube          FLOAT NULL,
    TotalWeight   FLOAT NULL,
    TotalCube     FLOAT NULL,
    --(Wan01) - END
    Domain NVARCHAR(10)  NULL, --GOH01
    ConsigneeKey   NVARCHAR(45), --CS01
    ExpArrivalTime NVARCHAR(30) NULL, --(CS02) 
    TotalCnt       INT NULL,          --(CS02)
    CLong          NVARCHAR(100) NULL) --(CS02)

   --(Wan04) - START
   SELECT TOP 1 @c_Storerkey = OH.Storerkey
   FROM MBOLDETAIL MB WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)
   WHERE MB.MBOLKey = @c_MBOLKey
   ORDER BY MB.MBOLLineNumber

   SELECT @n_SetMBOLAsOrd        = ISNULL(MAX(CASE WHEN Code = 'SETMBOLASORD' THEN 1 ELSE 0 END),0)
         ,@n_OrderShipAddress    = ISNULL(MAX(CASE WHEN Code = 'ORDERSHIPADDRESS' THEN 1 ELSE 0 END),0)
         ,@n_WgtCubeFromPackInfo = ISNULL(MAX(CASE WHEN Code = 'WGTCUBEFROMPACKINFO' THEN 1 ELSE 0 END),0)
         ,@n_CountCntByLabelno   = ISNULL(MAX(CASE WHEN Code = 'COUNTCARTONBYLABELNO' THEN 1 ELSE 0 END),0)  --(Wan07)
         ,@n_PrintAfterPacked    = ISNULL(MAX(CASE WHEN Code = 'PRINTAFTERPACKED'   THEN 1 ELSE 0 END),0)    --(Wan08)
         ,@c_showfield           = ISNULL(MAX(CASE WHEN Code = 'ShowField'   THEN 1 ELSE 0 END),0)        --(CS01)
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND   Storerkey= @c_Storerkey
   AND   Long = 'r_dw_pod_05'
   AND   ISNULL(Short,'') <> 'N'
   --(Wan04) - END
    
   --(Wan08) - START
   IF @n_PrintAfterPacked = 1 
   BEGIN
      IF EXISTS (
                  SELECT 1 
                  FROM MBOLDETAIL MB WITH (NOLOCK)
                  JOIN ORDERS     OH WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)
                  WHERE MB.MBOLKey = @c_mbolkey
                  AND OH.Status < '5'
                )
      BEGIN
         GOTO QUIT
      END
   END
   --(Wan08) - END
   
   --NJOW01
   SELECT DISTINCT STORER.Storerkey, CASE WHEN ISNULL(CODELKUP.Code,'') <> '' THEN 
                                 CODELKUP.UDF01 
                            ELSE STORER.SUSR1 END AS SUSR1_UDF01
   INTO #TMP_STORER
   FROM ORDERS (NOLOCK)
   JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
   LEFT JOIN CODELKUP (NOLOCK) ON ORDERS.Storerkey = CODELKUP.Storerkey AND CODELKUP.Listname = 'PODBARCODE'
   WHERE ORDERS.Mbolkey = @c_Mbolkey

    INSERT INTO #POD
    ( mbolkey,        MbolLineNumber ,    ExternOrderKey,        Orderkey,        type,
      EditDate,       Company,            CaseCnt,               Qty,                      
      TotalCaseCnt,   TotalQty,           leadtime,              Logo,
      B_Address1,     B_Contact1,         B_Phone1,              B_Fax1,
      Susr2,          MbolLoadkey,        ShipTo,                ShipToAdd1,
      ShipToAdd2,     ShipToAdd3,         ShipToAdd4,            ShipToCity,
      ShipToContact1, ShipToContact2,     ShipToPhone1,          ShipToPhone2,
      note1a,         note1b,             note2a,                note2b,
      Weight,         Cube,               TotalWeight,           TotalCube,                        --(Wan01)
      Domain,ConsigneeKey , ExpArrivalTime,TotalCnt,CLong)    --GOH01   --CS01  --(CS02) 
    SELECT 
      a.mbolkey,     b.MbolLineNumber,    b.ExternOrderKey,    b.Orderkey,    c.type,        
      a.editdate,    f.company,           0,                   0,
      0,             0,                   ISNULL(CAST(e.Short AS int),0),     f.logo,
      f.B_Address1,  f.B_Contact1,        f.B_Phone1,          f.B_fax1,
      f.Susr2,    
         --c=order d=consignee f=storer h=billto+consignee
         --NJOW01 Start
         CASE WHEN ISNULL(j.Susr1_UDF01,0) & 4 = 4 THEN c.MBOLKey
              ELSE c.Loadkey END AS Mbolloadkey,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Company ELSE h.Company END   --(Wan02)
              ELSE  
                CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   '('+RTRIM(d.Storerkey) + ')' + d.Company
                ELSE 
                CASE WHEN ISNULL(j.Susr1_UDF01,0) & 8 = 8 THEN
                       '('+RTRIM(ISNULL(c.Consigneekey,'')) + '-' + RTRIM(ISNULL(c.Billtokey,'')) +')' + c.C_Company
                ELSE '('+RTRIM(ISNULL(c.Consigneekey,''))+')'+c.C_Company END 
              END 
         END AS Shipto,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address1 ELSE h.Address1 END --(Wan02) 
              ELSE  
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Address1 ELSE c.C_Address1 END 
         END AS ShipToAdd1,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address2 ELSE h.Address2 END --(Wan02)  
              ELSE  
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Address2 ELSE c.C_Address2 END 
         END AS ShipToAdd2,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address3 ELSE h.Address3 END --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Address3 ELSE c.C_Address3 END 
         END AS ShipToAdd3,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address4 ELSE h.Address4 END --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Address4 ELSE c.C_Address4 END 
         END AS ShipToAdd4,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_City ELSE h.City END         --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.City ELSE c.C_City END 
         END AS ShipToCity,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Contact1 ELSE h.Contact1 END --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Contact1 ELSE c.C_Contact1 END 
         END AS ShipToContact1,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Contact2 ELSE h.Contact2 END --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Contact2 ELSE c.C_Contact2 END 
         END AS ShipToContact2,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Phone1 ELSE h.Phone1 END     --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Phone1 ELSE c.C_Phone1 END 
         END AS ShipToPhone1,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Phone2 ELSE h.Phone2 END     --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Phone2 ELSE c.C_Phone2 END 
         END AS ShipToPhone2, 
         --NJOW01 End
         /*
         CASE WHEN ISNULL(f.Susr1,0) & 4 = 4 THEN c.MBOLKey
              ELSE c.Loadkey END AS Mbolloadkey,
         --(Wan01) - START  
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Company ELSE h.Company END   --(Wan02)
              ELSE  
              CASE WHEN ISNULL(f.Susr1,0) & 2 = 2 THEN
                 '('+RTRIM(d.Storerkey) + ')' + d.Company
              ELSE 
              CASE WHEN ISNULL(f.Susr1,0) & 8 = 8 THEN
                     '('+RTRIM(ISNULL(c.Consigneekey,'')) + '-' + RTRIM(ISNULL(c.Billtokey,'')) +')' + c.C_Company
              ELSE '('+RTRIM(ISNULL(c.Consigneekey,''))+')'+c.C_Company END 
              END 
         END AS Shipto,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address1 ELSE h.Address1 END --(Wan02) 
              ELSE  
              CASE WHEN ISNULL(f.Susr1,0) & 2 = 2 THEN
                   d.Address1 ELSE c.C_Address1 END 
         END AS ShipToAdd1,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address2 ELSE h.Address2 END --(Wan02)  
              ELSE  
              CASE WHEN ISNULL(f.Susr1,0) & 2 = 2 THEN
                   d.Address2 ELSE c.C_Address2 END 
         END AS ShipToAdd2,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address3 ELSE h.Address3 END --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(f.Susr1,0) & 2 = 2 THEN
                   d.Address3 ELSE c.C_Address3 END 
         END AS ShipToAdd3,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address4 ELSE h.Address4 END --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(f.Susr1,0) & 2 = 2 THEN
                   d.Address4 ELSE c.C_Address4 END 
         END AS ShipToAdd4,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_City ELSE h.City END         --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(f.Susr1,0) & 2 = 2 THEN
                   d.City ELSE c.C_City END 
         END AS ShipToCity,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Contact1 ELSE h.Contact1 END --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(f.Susr1,0) & 2 = 2 THEN
                   d.Contact1 ELSE c.C_Contact1 END 
         END AS ShipToContact1,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Contact2 ELSE h.Contact2 END --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(f.Susr1,0) & 2 = 2 THEN
                   d.Contact2 ELSE c.C_Contact2 END 
         END AS ShipToContact2,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Phone1 ELSE h.Phone1 END     --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(f.Susr1,0) & 2 = 2 THEN
                   d.Phone1 ELSE c.C_Phone1 END 
         END AS ShipToPhone1,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Phone2 ELSE h.Phone2 END     --(Wan02)  
              ELSE 
              CASE WHEN ISNULL(f.Susr1,0) & 2 = 2 THEN
                   d.Phone2 ELSE c.C_Phone2 END 
         END AS ShipToPhone2, 
         --(Wan02) - END
         */
         --LEFT(CONVERT(char(430),f.Notes1),215) AS note1a,
         --SUBSTRING(CONVERT(char(430),f.Notes1),216,215) AS note1b,
         --LEFT(CONVERT(char(430),f.Notes2),215) AS note2a,
         --SUBSTRING(CONVERT(char(430),f.Notes2),216,215) AS note2b, 
         LEFT(CONVERT(NVARCHAR(430),f.Notes1),216) AS note1a,
         SUBSTRING(CONVERT(NVARCHAR(430),f.Notes1),217,214) AS note1b,
         LEFT(CONVERT(NVARCHAR(430),f.Notes2),216) AS note2a,
         SUBSTRING(CONVERT(NVARCHAR(430),f.Notes2),217,214) AS note2b, 
         ISNULL(b.Weight,0),
         ISNULL(b.Cube,0),
         0,
         0,
         --(Wan01) - END 
         g.Short  --GOH01
         ,CASE WHEN @c_showfield='1' AND ISNULL(c.ConsigneeKey,'') <> '' THEN c.ConsigneeKey ELSE '' END
         ,ISNULL(e.UDF01,''),0                                        --(CS02)
         ,ISNULL(LTRIM(g.long),'')                                     --(CS02)
    FROM MBOL a (nolock) JOIN MBOLDETAIL b  WITH (nolock) ON a.mbolkey = b.mbolkey
    JOIN ORDERS c WITH (nolock) ON b.orderkey = c.orderkey
    LEFT JOIN STORER d WITH (nolock) ON c.consigneekey = d.storerkey
    --(Wan03) - START
    --LEFT JOIN Codelkup e WITH (nolock) ON c.Consigneekey = e.Code and c.Storerkey = e.Long and e.listname ='CityLdTime'
    --(Wan03) - END
    --(Wan03) - START
    JOIN STORER f WITH (nolock) ON c.storerkey = f.storerkey    
    LEFT JOIN STORERCONFIG  i WITH (NOLOCK) ON (i.Storerkey = c.Storerkey)
                                            AND(i.Configkey = 'CityLdTimeField')
    LEFT JOIN CODELKUP e WITH (nolock) ON e.listname ='CityLdTime' 
                                       AND ( (i.SValue = '1' AND e.Description = c.C_City) OR
                                             (i.SValue = '2' AND e.Description = f.City) OR
                                             (i.SValue = '3' AND e.Description = c.Consigneekey) OR
                                             (i.SValue = '4' AND e.Description = + RTRIM(c.BillTokey) + RTRIM(c.Consigneekey)) )
                                       AND ( (ISNULL(RTRIM(e.Long),'')= '') OR 
                                             (ISNULL(RTRIM(e.Long),'') <> '' AND ISNULL(RTRIM(e.Long),'') = c.Facility) )
                                       AND CONVERT( NVARCHAR(15), e.Notes) = i.Storerkey
                                       AND ( (CONVERT( NVARCHAR(50), e.Notes2) = c.IntermodalVehicle) OR
                                             (CONVERT( NVARCHAR(50), e.Notes2) = 'ROAD' AND ISNULL(RTRIM(c.IntermodalVehicle),'') = '') )
                                       
    --(Wan03) - END
                                         
    LEFT JOIN Codelkup g WITH (nolock) ON c.Storerkey = g.Code and g.listname ='STRDOMAIN'   --GOH01
    --(Wan01) - START
    LEFT JOIN STORER h WITH (NOLOCK) ON RTRIM(c.Billtokey) + RTRIM(c.Consigneekey) = h.storerkey   
    --(Wan01) - END  
    JOIN #TMP_STORER j WITH (NOLOCK) ON c.Storerkey = j.Storerkey --NJOW01
    WHERE a.mbolkey = @c_mbolkey 
              


    SELECT @c_orderkey = MIN(orderkey)
    FROM #POD (nolock)
    
    WHILE @c_orderkey IS NOT NULL
    BEGIN 
      SELECT @c_type = type
      FROM #POD (nolock)
      WHERE orderkey = @c_orderkey 
      
      SELECT @n_casecnt = 0, @n_qty = 0
      
      --IF @c_type = 'XDOCK' 
      IF EXISTS(SELECT code FROM CODELKUP(NOLOCK) WHERE listname = 'XDOCKTYPE' AND code = @c_type) 
         AND @n_CountCntByLabelno = 0                                                              --(Wan09)
      BEGIN
         SELECT @n_casecnt = COUNT(DISTINCT d.UserDefine01+d.UserDefine02),
                @n_qty     = SUM(d.qtyallocated + d.ShippedQty + d.QtyPicked)
         FROM ORDERDETAIL d (nolock)
         WHERE d.orderkey = @c_orderkey and d.status >= '5' 
         AND d.qtyallocated + d.qtypicked + d.shippedqty > 0
      END
      ELSE
      BEGIN
         --(Wan07) - START
         --SELECT @n_casecnt = COUNT(DISTINCT f.cartonno),
         SELECT @n_casecnt = CASE WHEN @n_CountCntByLabelno = 0 
                                  THEN COUNT(DISTINCT f.cartonno)
                                  ELSE COUNT(DISTINCT f.labelno)
                                  END,
         --(Wan07) - END
                @n_qty     = SUM(f.qty)
         FROM PICKHEADER e (nolock), PACKDETAIL f (nolock)
         WHERE e.orderkey = @c_orderkey and e.PickHeaderKey = f.pickslipno 
      END
       
      --(Wan04) - START
      --(CS02) -Start
      
      SELECT @n_TTLCnt = SUM(totalcartons)
      FROM MBOLDETAIL  WITH (NOLOCK)
      WHERE MbolKey = @c_mbolkey
      
      --(CS02) END
      IF @n_SetMBOLAsOrd = 1
      BEGIN
         UPDATE #POD
          SET MBOLKey     = @c_Orderkey
            , MbolLoadkey = @c_Orderkey
            , Totalcasecnt= @n_casecnt 
            , Totalqty    = @n_qty
            , TotalCnt = @n_TTLCnt               --(CS02)
         WHERE Orderkey = @c_Orderkey
      END

      IF @n_OrderShipAddress = 1
      BEGIN
         --(Wan05) - START
         SET @c_Brand = ''
         SELECT TOP 1 @c_Brand = ISNULL(RTRIM(SKU.BUSR5),'')
         FROM ORDERDETAIL OD  WITH (NOLOCK)
         JOIN SKU         SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey)
                                            AND(OD.Sku = SKU.Sku)
         WHERE OD.Orderkey = @c_Orderkey

         SET @c_Brand = @c_Brand + CASE WHEN @c_Brand = '' THEN '' ELSE ' ' END
         --(Wan05) - END

         UPDATE #POD
          SET Shipto        = @c_Brand + ISNULL(RTRIM(ORDERS.C_Company),'') -- (Wan05)
            , ShipToAdd1    = ISNULL(RTRIM(ORDERS.C_Address1),'')  
            , ShipToAdd2    = ISNULL(RTRIM(ORDERS.C_Address2),'')
            , ShipToAdd3    = ISNULL(RTRIM(ORDERS.C_Address3),'')
            , ShipToAdd4    = ISNULL(RTRIM(ORDERS.C_Address4),'')
            , ShipToCity    = ISNULL(RTRIM(ORDERS.C_City),'')
            , ShipToContact1= ISNULL(RTRIM(ORDERS.C_Contact1),'')
            , ShipToContact2= ISNULL(RTRIM(ORDERS.C_Contact2),'') 
            , ShipToPhone1  = ISNULL(RTRIM(ORDERS.C_Phone1),'')
            , ShipToPhone2  = ISNULL(RTRIM(ORDERS.C_Phone2),'')
         FROM #POD 
         JOIN ORDERS (NOLOCK) ON (#POD.Orderkey = ORDERS.Orderkey)  --tlting01
         WHERE #POD.Orderkey = @c_Orderkey
      END

      IF @n_WgtCubeFromPackInfo = 1
      BEGIN
         SET @n_Weight = 0.00
         SET @n_Cube   = 0.00

         SELECT @n_Weight = ISNULL(SUM(ISNULL(PI.Weight,0)),0)
              , @n_Cube   = ISNULL(SUM(ISNULL(PI.Cube,0)),0)                                                      --(Wan06)
         FROM PACKHEADER PH WITH (NOLOCK)
         JOIN PACKINFO   PI WITH (NOLOCK) ON (PH.PickSlipNo = PI.PickSlipNo)
         WHERE PH.Orderkey = @c_Orderkey

         SELECT @n_Weight = ISNULL(CASE WHEN @n_Weight > 0 THEN @n_Weight ELSE SUM(PD.Qty * S.StdGrossWgt) END,0)
               --,@n_Cube   = ISNULL(SUM(PD.Qty * S.StdCube),0)                                                   --(Wan06)
               ,@n_Cube   = ISNULL(CASE WHEN @n_Cube > 0 THEN @n_Cube ELSE SUM(PD.Qty * S.StdCube) END,0)         --(Wan06) 
         FROM PACKHEADER PH WITH (NOLOCK)
         JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         JOIN SKU        S  WITH (NOLOCK) ON (PD.Storerkey = S.Storerkey) AND (PD.Sku = S.Sku)
         WHERE PH.Orderkey = @c_Orderkey
 
         UPDATE #POD
          SET Weight = @n_Weight
            , Cube   = @n_Cube
            , TotalWeight = @n_Weight                                                               
            , TotalCube   = @n_Cube 
            , TotalCnt = @n_TTLCnt               --(CS02)
         FROM #POD 
         WHERE Orderkey = @c_Orderkey
      END
      --(Wan04) - END

      UPDATE #POD                
      SET casecnt = @n_casecnt,
          qty     = @n_qty
      WHERE orderkey = (SELECT TOP 1 Orderkey          --(CS02)
                        FROM #POD                      --(CS02)
                        Where Orderkey = @c_orderkey   --(CS02)
                        ORDER BY #POD.Orderkey )       --(CS02)     
     
          
      SELECT @c_orderkey = MIN(orderkey)
      FROM #POD (nolock)
      WHERE orderkey > @c_orderkey
    END
    
   IF @n_SetMBOLAsOrd = 0                                                                          --(Wan04)
   BEGIN
    SELECT @n_totalcasecnt = SUM(casecnt),
           @n_totalqty     = SUM(qty) 
         , @n_TotalWeight  = SUM(Weight)                                                           --(Wan01) 
         , @n_TotalCube    = SUM(Cube)                                                             --(Wan01) 
    FROM #POD
    
    UPDATE TOP (1) #POD                                                                             --(CS02)
    SET totalcasecnt = @n_totalcasecnt,
        totalqty     = @n_totalqty
      , TotalWeight  = @n_TotalWeight                                                              --(Wan01) 
      , TotalCube    = @n_TotalCube                                                                --(Wan01)
      , TotalCnt     = @n_TTLCnt                                                                    --(CS02)
   END

   QUIT:                                                                                           --(Wan08) 
    SELECT *, ISNULL(@c_exparrivaldate,'')
         , @c_printdate, @c_printby                                                                --(Wan08) 
    FROM #POD
END

GO