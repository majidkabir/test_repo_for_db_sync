SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_pod_04                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose: C&A POD                                                     */
/*                                                                      */
/* Called By: r_dw_pod_04  SOS#169653                                   */
/*                                                                      */
/* Parameters: (Input)  @c_mbolkey   = MBOL No                          */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 18-May-2010  Vanessa  1.1  SOS#169653TotCtnCube 2decimals.(Vanessa01)*/
/* 20-Jul-2010  GTGOH    1.2  SOS#180015 - Insert POD Barcode for       */
/*                            Codelkup.Listname='STRDOMAIN' (GOH01)     */
/* 16-Apr-2012  NJOW01   1.3  241190-241190-C&A POD add carton type and */
/*                            sku type columns                          */
/* 25-May-2012  YTWan    1.4  SOS#245082-Add new UOM -SUN, SUS.  get*/
/*                            Pack.PackDesc. (Wan01)                    */
/* 22-Aug-2012  SPChin   1.5  SOS253934 - Bug Fixed                     */
/* 18-Apr-2014  NJOW02   1.6  309058-able to print by consignee         */
/* 01-Sep-2016  NJOW03   1.7  WMS-239: Change busr3 reference values    */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_pod_04]
        @c_MbolKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Logo            NVARCHAR(60),
           @c_Company         NVARCHAR(45),
           @c_ConsigneeKey    NVARCHAR(15),
           @c_Address1        NVARCHAR(45),
           @c_Address2        NVARCHAR(45),
           @c_Address3        NVARCHAR(45),
           @c_Contact1        NVARCHAR(30),
           @c_Phone1          NVARCHAR(18),
           @c_Phone2          NVARCHAR(18),
           @d_ArrivalDate     DATETIME,
           @c_Notes1          NVARCHAR(100),
           @c_LoadKey         NVARCHAR(10),
           @n_TotalCtnCnt     INT,
           @n_TotCtnCube      FLOAT, -- (Vanessa01)
           @c_UOM             NVARCHAR(10),
           @c_BUSR3           NVARCHAR(30),
           @n_QTY1            INT,
           @n_QTY2            INT,
           @n_QTY3            INT,
           @n_QTY4            INT,
           @n_QTY5            INT,
           @n_CityLdTime      INT,
           @n_QTY             INT,
           @c_City            NVARCHAR(45),
           @c_Facility        NVARCHAR(5),
           @c_Domain          NVARCHAR(10),    --GOH01
           @c_ctntyp1         NVARCHAR(10)
         , @c_PackDescr       NVARCHAR(60)    --(Wan01)

   CREATE TABLE #POD
   (MbolKey           NVARCHAR(10)      NULL,
    Logo              NVARCHAR(60)      NULL,
    Company           NVARCHAR(45)      NULL,
    ConsigneeKey      NVARCHAR(15)      NULL,
    Address1          NVARCHAR(45)      NULL,
    Address2          NVARCHAR(45)      NULL,
    Address3          NVARCHAR(45)      NULL,
    Contact1          NVARCHAR(30)      NULL,
    Phone1            NVARCHAR(18)      NULL,
    Phone2            NVARCHAR(18)      NULL,
    ArrivalDate       DATETIME      NULL,
    Notes1            NVARCHAR(100)  NULL,
    LoadKey           NVARCHAR(10)      NULL,
    TotalCtnCnt       INT           NULL,
    TotCtnCube        DECIMAL(15,2) NULL,  -- (Vanessa01)
    UOM               NVARCHAR(10)      NULL,
    QTY1              INT           NULL,
    QTY2              INT           NULL,
    QTY3              INT           NULL,
    QTY4              INT           NULL,
    QTY5              INT           NULL,
    Domain            NVARCHAR(10)      NULL,
    Ctntyp1           NVARCHAR(10)      NULL)   --GOH01

   DECLARE CUR_HEADER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT S2.Logo,
          S1.Company,
          O.ConsigneeKey,
          S1.Address1,
          S1.Address2,
          S1.Address3,
          S1.Contact1,
          S1.Phone1,
          S1.Phone2,
          CAST(S1.Notes1 AS NVARCHAR(100)) AS Notes1,
          LP.LoadKey,
          ISNULL(LP.CtnCnt1, 0)+ISNULL(LP.CtnCnt2, 0)+ISNULL(LP.CtnCnt3, 0)+ISNULL(LP.CtnCnt4, 0)+ISNULL(LP.CtnCnt5, 0) AS TotalCtnCnt,
          ISNULL(LP.TotCtnCube, 0) AS TotCtnCube,
          --OD.UOM,
          ISNULL(RTRIM(PACK.PACKDescr),''),                                                         --(Wan01)
          S1.City,
          O.Facility,
          CLK.Short,   --GOH01
          LP.ctntyp1
   from MBOL M WITH (NOLOCK)
   JOIN Orders O WITH (NOLOCK) ON (M.MBOLKey = O.MBOLKey)
   JOIN OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
   JOIN LoadPlan LP WITH (NOLOCK) ON (O.LoadKey = LP.LoadKey)
   JOIN Storer S1 WITH (NOLOCK) ON (O.ConsigneeKey  = S1.StorerKey)
   JOIN Storer S2 WITH (NOLOCK) ON (O.StorerKey = S2.StorerKey)
   LEFT JOIN Codelkup CLK (nolock) ON O.Storerkey = CLK.Code and CLK.listname ='STRDOMAIN'   --GOH01
   JOIN PACK WITH (NOLOCK) ON (OD.Packkey = PACK.Packkey)                                           --(Wan01)
   WHERE M.MBOLKey = @c_MbolKey

   OPEN CUR_HEADER
   FETCH NEXT FROM CUR_HEADER INTO @c_Logo,        @c_Company,       @c_ConsigneeKey,  @c_Address1,   @c_Address2, @c_Address3,
                                   @c_Contact1,    @c_Phone1,        @c_Phone2,        @c_Notes1,     @c_LoadKey,
                                 --@n_TotalCtnCnt, @n_TotCtnCube,    @c_UOM,           @c_City,       @c_Facility, --(Wan01)
                                   @n_TotalCtnCnt, @n_TotCtnCube,    @c_PackDescr,     @c_City,       @c_Facility, --(Wan01)
                                   @c_Domain,      @c_ctntyp1    --GOH01

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @d_ArrivalDate   = NULL
      SELECT @n_CityLdTime    = 0
      SELECT @n_QTY1          = 0
      SELECT @n_QTY2          = 0
      SELECT @n_QTY3          = 0
      SELECT @n_QTY4          = 0
      SELECT @n_QTY5          = 0

      SELECT @n_CityLdTime = Ceiling(Cast(Short AS REAL))
      FROM Codelkup WITH (NOLOCK)
      WHERE Listname = 'CityLdTime'
         AND Description = @c_City
         AND Long = @c_Facility
         AND CAST(Notes AS NVARCHAR(3)) = 'CNA'
         AND ISNUMERIC(Short) = 1

      IF @n_CityLdTime <> 0
      BEGIN
         SELECT @d_ArrivalDate = DateAdd(Day, @n_CityLdTime, GetDate())
      END

      DECLARE CUR_DETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      select --OD.UOM                                                                              --(Wan01)
             ISNULL(RTRIM(PACK.PackDescr),'')                                                      --(Wan01)
           , SKU.BUSR3
           --, ISNULL(SUM(PD.QTY * CASE WHEN OD.UOM = 'SUP' THEN BOM.Qty ELSE 1 END)               --(Wan01),SOS253934
           , ISNULL(SUM(PD.QTY * CASE WHEN OD.UOM <> 'PCS' THEN BOM.Qty ELSE 1 END),0)             --(Wan01),SOS253934
           --  CASE WHEN OD.UOM = 'SUP'                                                            --(Wan01)
           --       THEN SUM(PD.QTY * BOM.QTY)                                                     --(Wan01)
           --  ELSE                                                                                --(Wan01)
           --       SUM(PD.QTY)                                                                    --(Wan01)
           --  END                                                                                 --(Wan01)

      from Orders O WITH (NOLOCK)
      JOIN OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
      JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
      JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      JOIN PACK WITH (NOLOCK) ON (OD.PackKey = PACK.Packkey)                                       --(Wan01)
      LEFT OUTER JOIN BillOfMaterial BOM WITH (NOLOCK) ON (PD.StorerKey = BOM.StorerKey AND PD.SKU = BOM.SKU)
      WHERE O.MBOLKey = @c_MbolKey
      AND O.LoadKey = @c_LoadKey      
      --AND OD.UOM = @c_UOM                                                                        --(Wan01)
      AND ISNULL(RTRIM(PACK.PACKDescr),'') = @c_PackDescr                                          --(Wan01)
      AND O.Consigneekey = @c_ConsigneeKey --NJOW02
      GROUP BY --OD.UOM, SKU.BUSR3                                                                 --(Wan01)
               SKU.BUSR3, ISNULL(RTRIM(PACK.PackDescr),'')                                         --(Wan01)


      OPEN CUR_DETAIL
      FETCH NEXT FROM CUR_DETAIL INTO @c_UOM, @c_BUSR3, @n_QTY

      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF ISNULL(RTRIM(@c_BUSR3), '') = 'JDV' --'D1' NJOW03  
         BEGIN
            SELECT @n_QTY1 = @n_QTY
         END

         IF ISNULL(RTRIM(@c_BUSR3), '') = 'LAC' --'D2'
         BEGIN
            SELECT @n_QTY2 = @n_QTY
         END

         IF ISNULL(RTRIM(@c_BUSR3), '') = 'LDV' --'D3'
         BEGIN
            SELECT @n_QTY3 = @n_QTY
         END

         IF ISNULL(RTRIM(@c_BUSR3), '') = 'MAC' --'D4'
         BEGIN
            SELECT @n_QTY4 = @n_QTY
         END

         IF ISNULL(RTRIM(@c_BUSR3), '') = 'MDV' --'D5'
         BEGIN
            SELECT @n_QTY5 = @n_QTY
         END

         FETCH NEXT FROM CUR_DETAIL INTO @c_UOM, @c_BUSR3, @n_QTY
      END  --CUR_DETAIL

      CLOSE CUR_DETAIL
      DEALLOCATE CUR_DETAIL

      INSERT INTO #POD
      (MbolKey,   Logo,       Company,       ConsigneeKey,  Address1,      Address2,
       Address3,  Contact1,   Phone1,        Phone2,        ArrivalDate,
       Notes1,    LoadKey,    TotalCtnCnt,   TotCtnCube,    UOM,
       QTY1,      QTY2,       QTY3,          QTY4,          QTY5, Domain, Ctntyp1)
      VALUES(@c_MbolKey,   @c_Logo,       @c_Company,       @c_ConsigneeKey,  @c_Address1,   @c_Address2,
             @c_Address3,  @c_Contact1,   @c_Phone1,        @c_Phone2,        @d_ArrivalDate,
             @c_Notes1,    @c_LoadKey,    @n_TotalCtnCnt,   @n_TotCtnCube,    @c_UOM,
             @n_QTY1,      @n_QTY2,       @n_QTY3,          @n_QTY4,          @n_QTY5, @c_Domain, @c_ctntyp1)  --GOH01

      FETCH NEXT FROM CUR_HEADER INTO @c_Logo,        @c_Company,       @c_ConsigneeKey,  @c_Address1,   @c_Address2, @c_Address3,
                                      @c_Contact1,    @c_Phone1,        @c_Phone2,        @c_Notes1,     @c_LoadKey,
                                    --@n_TotalCtnCnt, @n_TotCtnCube,    @c_UOM,           @c_City,       @c_Facility, --(Wan01)
                                      @n_TotalCtnCnt, @n_TotCtnCube,    @c_PackDescr,     @c_City,       @c_Facility, --(Wan01)
                                      @c_Domain,      @c_ctntyp1     --GOH01
   END   --CUR_HEADER

   CLOSE CUR_HEADER
   DEALLOCATE CUR_HEADER

   SELECT * FROM #POD (NOLOCK)

   DROP TABLE #POD
END

GO