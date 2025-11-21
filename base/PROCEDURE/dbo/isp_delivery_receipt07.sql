SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_delivery_receipt07                             */  
/* Creation Date: 04-Sep-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-14879 - NIKEPH Packing List                             */  
/*                                                                      */  
/*                                                                      */  
/* Called By: report dw = r_dw_delivery_receipt07                       */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_delivery_receipt07] (  
   @c_MBOLKey NVARCHAR(10),
   @c_ShipTo  NVARCHAR(50) = '',
   @c_Type    NVARCHAR(5) = 'H1'
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
  DECLARE @c_Externpokey NVARCHAR(100), @c_ExternOrderkey NVARCHAR(100), @c_CaseID NVARCHAR(100), @c_BUSR10a NVARCHAR(100), 
          @c_DESCR NVARCHAR(100), @c_BUSR10b NVARCHAR(250), @c_Qty NVARCHAR(250),
          @b_Success        INT,  
          @n_err            INT,  
          @c_errmsg         NVARCHAR(255),
          @c_GetPackListNo  NVARCHAR(10),
          @n_continue       INT = 1,
          @c_Consigneekey   NVARCHAR(50),
          @n_StartTCnt      INT
                   
   DECLARE @c_CountConsigneekey    INT
          
   DECLARE @c_SeqNo   NVARCHAR(100), @c_ColValue   NVARCHAR(100),
           @c_Size1   NVARCHAR(10),
           @c_Size2   NVARCHAR(10),
           @c_Size3   NVARCHAR(10),
           @c_Size4   NVARCHAR(10),
           @c_Size5   NVARCHAR(10),
           @c_Size6   NVARCHAR(10),
           @c_Size7   NVARCHAR(10),
           @c_Size8   NVARCHAR(10),
           @c_Size9   NVARCHAR(10),
           @c_Size10  NVARCHAR(10),
           @c_Size11  NVARCHAR(10),
           @c_Size12  NVARCHAR(10),
           @c_Size13  NVARCHAR(10),
           @c_Size14  NVARCHAR(10),
           @c_Size15  NVARCHAR(10),
           @c_Size16  NVARCHAR(10),
           @c_Size17  NVARCHAR(10),
           @c_Size18  NVARCHAR(10),
           @c_Size19  NVARCHAR(10),
           @c_Size20  NVARCHAR(10),
           @c_Size21  NVARCHAR(10),
           @c_Size22  NVARCHAR(10),
           @c_Size23  NVARCHAR(10),
           @c_Size24  NVARCHAR(10),
           
           @n_Qty1    INT = 0,
           @n_Qty2    INT = 0,
           @n_Qty3    INT = 0,
           @n_Qty4    INT = 0,
           @n_Qty5    INT = 0,
           @n_Qty6    INT = 0,
           @n_Qty7    INT = 0,
           @n_Qty8    INT = 0,
           @n_Qty9    INT = 0,
           @n_Qty10   INT = 0,
           @n_Qty11   INT = 0,  
           @n_Qty12   INT = 0,  
           @n_Qty13   INT = 0,  
           @n_Qty14   INT = 0,  
           @n_Qty15   INT = 0,  
           @n_Qty16   INT = 0,  
           @n_Qty17   INT = 0,  
           @n_Qty18   INT = 0,  
           @n_Qty19   INT = 0,  
           @n_Qty20   INT = 0,  
           @n_Qty21   INT = 0,  
           @n_Qty22   INT = 0,  
           @n_Qty23   INT = 0,  
           @n_Qty24   INT = 0  
   
   SELECT @n_StartTCnt = @@TRANCOUNT
   
   IF @c_Type = 'H1'
   BEGIN
      SELECT DISTINCT OH.MBOLKey, OH.ConsigneeKey
      FROM Orders OH (NOLOCK)
      WHERE OH.MBOLKey = @c_MBOLKey
      
      GOTO QUIT_SP
   END
   
   CREATE TABLE #TMP_CONKey (
   	Consigneekey   NVARCHAR(50) NULL,
   	UserDefine10   NVARCHAR(50) NULL
   )
   
   DECLARE   @c_GetConsigneekey    NVARCHAR(15)
   	     , @c_GetExternpokey     NVARCHAR(50)
   	     , @c_GetExternOrderkey  NVARCHAR(50)
   	     , @c_GetCaseID          NVARCHAR(20)
   	     , @c_GetItemClass       NVARCHAR(20)
   	     
   CREATE TABLE #TEMP_RECEIPT07_2 (
   	RowID          INT NOT NULL IDENTITY(1,1) 
    , Logo           NVARCHAR(50)  NULL  
    , Company        NVARCHAR(45)  NULL
    , Address1       NVARCHAR(45)  NULL
    , Address2       NVARCHAR(45)  NULL
    , Address3       NVARCHAR(45)  NULL
    , Address4       NVARCHAR(45)  NULL
    , VAT            NVARCHAR(50)  NULL
    , Consigneekey   NVARCHAR(15)  NULL
    , C_Company      NVARCHAR(45)  NULL
    , C_Address1     NVARCHAR(45)  NULL
    , C_Address2     NVARCHAR(45)  NULL
    , C_Address3     NVARCHAR(45)  NULL
    , C_Address4     NVARCHAR(45)  NULL
    , BillToKey      NVARCHAR(45)  NULL
    , B_Company      NVARCHAR(45)  NULL
    , Shipdate       DATETIME      NULL
    , Userdefine10   NVARCHAR(50)  NULL
    , MBOLKey        NVARCHAR(10)  NULL
    , OTMShipmentID  NVARCHAR(20)  NULL
    , Userdefine04   NVARCHAR(50)  NULL
    , Externpokey    NVARCHAR(50)  NULL
    , ExternOrderkey NVARCHAR(50)  NULL
    , CaseID         NVARCHAR(20)  NULL
    , Material       NVARCHAR(20)  NULL
    , DESCR          NVARCHAR(100) NULL
    , SIZE           NVARCHAR(MAX) NULL
    , qty            NVARCHAR(250) NULL
    , uom            NVARCHAR(10)  NULL
    , Size1          NVARCHAR(10)  NULL
    , Size2          NVARCHAR(10)  NULL
    , Size3          NVARCHAR(10)  NULL
    , Size4          NVARCHAR(10)  NULL
    , Size5          NVARCHAR(10)  NULL
    , Size6          NVARCHAR(10)  NULL
    , Size7          NVARCHAR(10)  NULL
    , Size8          NVARCHAR(10)  NULL
    , Size9          NVARCHAR(10)  NULL
    , Size10         NVARCHAR(10)  NULL
    , Size11         NVARCHAR(10)  NULL
    , Size12         NVARCHAR(10)  NULL
    , Size13         NVARCHAR(10)  NULL
    , Size14         NVARCHAR(10)  NULL
    , Size15         NVARCHAR(10)  NULL
    , Size16         NVARCHAR(10)  NULL
    , Size17         NVARCHAR(10)  NULL
    , Size18         NVARCHAR(10)  NULL
    , Size19         NVARCHAR(10)  NULL
    , Size20         NVARCHAR(10)  NULL
    , Size21         NVARCHAR(10)  NULL
    , Size22         NVARCHAR(10)  NULL
    , Size23         NVARCHAR(10)  NULL
    , Size24         NVARCHAR(10)  NULL
    , Qty1           INT           NULL
    , Qty2           INT           NULL
    , Qty3           INT           NULL
    , Qty4           INT           NULL
    , Qty5           INT           NULL
    , Qty6           INT           NULL
    , Qty7           INT           NULL
    , Qty8           INT           NULL
    , Qty9           INT           NULL
    , Qty10          INT           NULL
    , Qty11          INT           NULL
    , Qty12          INT           NULL
    , Qty13          INT           NULL
    , Qty14          INT           NULL
    , Qty15          INT           NULL
    , Qty16          INT           NULL
    , Qty17          INT           NULL
    , Qty18          INT           NULL
    , Qty19          INT           NULL
    , Qty20          INT           NULL
    , Qty21          INT           NULL
    , Qty22          INT           NULL
    , Qty23          INT           NULL
    , Qty24          INT           NULL
    , Countsku       INT           NULL
   )
   	     
   CREATE TABLE #TEMP_RECEIPT07_Final (
   	RowID          INT NOT NULL IDENTITY(1,1) 
    , Logo           NVARCHAR(50)  NULL  
    , Company        NVARCHAR(45)  NULL
    , Address1       NVARCHAR(45)  NULL
    , Address2       NVARCHAR(45)  NULL
    , Address3       NVARCHAR(45)  NULL
    , Address4       NVARCHAR(45)  NULL
    , VAT            NVARCHAR(50)  NULL
    , Consigneekey   NVARCHAR(15)  NULL
    , C_Company      NVARCHAR(45)  NULL
    , C_Address1     NVARCHAR(45)  NULL
    , C_Address2     NVARCHAR(45)  NULL
    , C_Address3     NVARCHAR(45)  NULL
    , C_Address4     NVARCHAR(45)  NULL
    , BillToKey      NVARCHAR(45)  NULL
    , B_Company      NVARCHAR(45)  NULL
    , Shipdate       DATETIME      NULL
    , Userdefine10   NVARCHAR(50)  NULL
    , MBOLKey        NVARCHAR(10)  NULL
    , OTMShipmentID  NVARCHAR(20)  NULL
    , Userdefine04   NVARCHAR(50)  NULL
    , Externpokey    NVARCHAR(50)  NULL
    , ExternOrderkey NVARCHAR(50)  NULL
    , CaseID         NVARCHAR(20)  NULL
    , Material       NVARCHAR(20)  NULL
    , DESCR          NVARCHAR(100) NULL
    , SIZE           NVARCHAR(MAX) NULL
    , qty            NVARCHAR(250) NULL
    , uom            NVARCHAR(10)  NULL
    , Size1          NVARCHAR(10)  NULL
    , Size2          NVARCHAR(10)  NULL
    , Size3          NVARCHAR(10)  NULL
    , Size4          NVARCHAR(10)  NULL
    , Size5          NVARCHAR(10)  NULL
    , Size6          NVARCHAR(10)  NULL
    , Size7          NVARCHAR(10)  NULL
    , Size8          NVARCHAR(10)  NULL
    , Size9          NVARCHAR(10)  NULL
    , Size10         NVARCHAR(10)  NULL
    , Size11         NVARCHAR(10)  NULL
    , Size12         NVARCHAR(10)  NULL
    , Size13         NVARCHAR(10)  NULL
    , Size14         NVARCHAR(10)  NULL
    , Size15         NVARCHAR(10)  NULL
    , Size16         NVARCHAR(10)  NULL
    , Size17         NVARCHAR(10)  NULL
    , Size18         NVARCHAR(10)  NULL
    , Size19         NVARCHAR(10)  NULL
    , Size20         NVARCHAR(10)  NULL
    , Size21         NVARCHAR(10)  NULL
    , Size22         NVARCHAR(10)  NULL
    , Size23         NVARCHAR(10)  NULL
    , Size24         NVARCHAR(10)  NULL
    , Qty1           INT           NULL
    , Qty2           INT           NULL
    , Qty3           INT           NULL
    , Qty4           INT           NULL
    , Qty5           INT           NULL
    , Qty6           INT           NULL
    , Qty7           INT           NULL
    , Qty8           INT           NULL
    , Qty9           INT           NULL
    , Qty10          INT           NULL
    , Qty11          INT           NULL
    , Qty12          INT           NULL
    , Qty13          INT           NULL
    , Qty14          INT           NULL
    , Qty15          INT           NULL
    , Qty16          INT           NULL
    , Qty17          INT           NULL
    , Qty18          INT           NULL
    , Qty19          INT           NULL
    , Qty20          INT           NULL
    , Qty21          INT           NULL
    , Qty22          INT           NULL
    , Qty23          INT           NULL
    , Qty24          INT           NULL
    , Countsku       INT           NULL
   )
   
   INSERT INTO #TMP_CONKey
   SELECT DISTINCT Consigneekey, UserDefine10
   FROM ORDERS (NOLOCK)
   WHERE MBOLKey = @c_MBOLKey 
   
   SELECT @c_CountConsigneekey = COUNT(1)
   FROM #TMP_CONKey
   
   IF @c_CountConsigneekey > 0
   BEGIN
      DECLARE CUR_Consignee CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT tc.Consigneekey
      FROM #TMP_CONKey AS tc
      WHERE ISNULL(tc.UserDefine10,'') = ''
      
      OPEN CUR_Consignee
      	
      FETCH NEXT FROM CUR_Consignee INTO @c_Consigneekey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
   	   EXECUTE nspg_getkey
               'NIKEPH_PLNo'
               , 10
               , @c_GetPackListNo  OUTPUT
               , @b_success        OUTPUT
               , @n_err            OUTPUT
               , @c_errmsg         OUTPUT

         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 74320   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain Packing List No . (isp_delivery_receipt07)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO QUIT_SP  
         END
         
         BEGIN TRAN
         
         UPDATE ORDERS
         SET Userdefine10 = @c_GetPackListNo, TrafficCop = NULL
         WHERE Consigneekey = @c_Consigneekey AND MBOLKey = @c_MBOLKey

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 74321   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update ORDERS Table Failed . (isp_delivery_receipt07)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO QUIT_SP  
         END
         
         FETCH NEXT FROM CUR_Consignee INTO @c_Consigneekey
      END
   END
  
   SELECT ST.Logo,
          ST.Company,
          ISNULL(ST.Address1,'') AS Address1,
          ISNULL(ST.Address2,'') AS Address2,
          ISNULL(ST.Address3,'') AS Address3,
          ISNULL(ST.Address4,'') AS Address4,
          ST.VAT,
          OH.Consigneekey, 
          OH.C_Company, 
          ISNULL(OH.C_Address1,'') AS C_Address1, 
          ISNULL(OH.C_Address2,'') AS C_Address2, 
          ISNULL(OH.C_Address3,'') AS C_Address3, 
          ISNULL(OH.C_Address4,'') AS C_Address4,
          OH.BillToKey, 
          OH.B_Company,
          MB.Shipdate,
          OH.Userdefine10,
          MB.MBOLKey,
          MB.OTMShipmentID, 
          US.Userdefine04,
          OH.Externpokey,
          OH.ExternOrderkey,
          PD.CaseID,
          SUBSTRING(ISNULL(S.BUSR10,''),1,10) AS Material, 
          S.DESCR,
          SUBSTRING(ISNULL(S.BUSR10,''),12,19) AS Size,
          SUM(PD.Qty) AS Qty,
          OD.UOM,
          (SELECT COUNT(DISTINCT ORDERDETAIL.SKU) FROM MBOLDETAIL (NOLOCK) JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = MBOLDETAIL.OrderKey
           JOIN ORDERDETAIL (NOLOCK) ON ORDERDETAIL.OrderKey = ORDERS.OrderKey AND ORDERS.Consigneekey = OH.Consigneekey
           WHERE MBOLDETAIL.MbolKey = @c_MBOLKey AND OH.Consigneekey = @c_ShipTo) AS CountSKU
   INTO #TEMP_RECEIPT07
   FROM MBOL MB (NOLOCK)
   JOIN MBOLDETAIL MD (NOLOCK) ON MD.MBOLKey = MB.MBOLKey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = MD.OrderKey
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey
   JOIN STORER ST (NOLOCK) ON OH.StorerKey = ST.StorerKey
   JOIN SKU S (NOLOCK) ON S.SKU = PD.Sku AND S.StorerKey = PD.Storerkey
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
                               AND OD.SKU = PD.SKU
   CROSS APPLY (SELECT TOP 1 UserDefine04 
                FROM ORDERDETAIL (NOLOCK)
                WHERE OrderKey = OH.OrderKey) AS US
   WHERE MB.MbolKey = @c_MBOLKey AND OH.Consigneekey = @c_ShipTo
   GROUP BY ST.Logo,
            ST.Company,
            ISNULL(ST.Address1,''),
            ISNULL(ST.Address2,''),
            ISNULL(ST.Address3,''),
            ISNULL(ST.Address4,''),
            ST.VAT,
            OH.Consigneekey, 
            OH.C_Company, 
            ISNULL(OH.C_Address1,''), 
            ISNULL(OH.C_Address2,''), 
            ISNULL(OH.C_Address3,''), 
            ISNULL(OH.C_Address4,''),
            OH.BillToKey, 
            OH.B_Company,
            MB.Shipdate,
            OH.Userdefine10,
            MB.MBOLKey,
            MB.OTMShipmentID, 
            US.Userdefine04,
            OH.Externpokey,
            OH.ExternOrderkey,
            PD.CaseID,
            SUBSTRING(ISNULL(S.BUSR10,''),1,10), 
            S.DESCR,
            SUBSTRING(ISNULL(S.BUSR10,''),12,19),
            OD.UOM
   --ORDER BY US.Userdefine04,
   --         OH.Externpokey,
   --         OH.ExternOrderkey,
   --         PD.CaseID,
   --         S.ItemClass, 
   --         S.DESCR,
   --         S.Size,
   --         OD.UOM
   
   --SELECT * INTO #TEMP_RECEIPT07_Final
   --FROM #TEMP_RECEIPT07
   --WHERE 1=2
   
   --SELECT * FROM #TEMP_RECEIPT07
   IF @c_Type = 'H2'
   BEGIN
   	SELECT DISTINCT
   	         Company       
   	       , Address1      
   	       , Address2      
   	       , Address3      
   	       , Address4      
   	       , VAT         
   	       , Logo  
   	       , Consigneekey  
   	       , C_Company     
   	       , C_Address1    
   	       , C_Address2    
   	       , C_Address3    
   	       , C_Address4    
   	       , BillToKey     
   	       , B_Company     
   	       , Shipdate      
   	       , Userdefine10  
   	       , MBOLKey       
   	       , OTMShipmentID 
   	FROM #TEMP_RECEIPT07
   	WHERE MBOLKey = @c_MBOLKey AND Consigneekey = @c_ShipTo
   	GOTO QUIT_SP
   END

   INSERT INTO #TEMP_RECEIPT07_2
   SELECT DISTINCT Logo, Company, Address1, Address2, Address3, Address4, VAT, Consigneekey,
                   C_Company, C_Address1, C_Address2, C_Address3, C_Address4,
                   BillToKey, B_Company, Shipdate, Userdefine10, MBOLKey,
                   OTMShipmentID, Userdefine04, Externpokey, ExternOrderkey, CaseID, Material, DESCR,
                   CAST(STUFF((SELECT '|' + RTRIM(Size) FROM #TEMP_RECEIPT07
                               --WHERE Size <> '' 
                               WHERE Externpokey = t.Externpokey
                               AND ExternOrderkey = t.ExternOrderkey
                               AND CaseID = t.CaseID
                               AND Material = t.Material
                               AND DESCR = t.DESCR
                               ORDER BY Externpokey, ExternOrderkey, CaseID, Material, DESCR
                               FOR XML PATH('')),1,1,'' ) AS NVARCHAR(250)) AS Size,
                   CAST(STUFF((SELECT '|' + RTRIM(Qty) FROM #TEMP_RECEIPT07 
                          --WHERE Qty > 0
                          WHERE Externpokey = t.Externpokey
                          AND ExternOrderkey = t.ExternOrderkey
                          AND CaseID = t.CaseID
                          AND Material = t.Material
                          AND DESCR = t.DESCR
                          ORDER BY Externpokey, ExternOrderkey, CaseID, Material, DESCR 
                          FOR XML PATH('')),1,1,'' ) AS NVARCHAR(250)) AS Qty, UOM,
                   SPACE(10) AS Size1,
                   SPACE(10) AS Size2,
                   SPACE(10) AS Size3,
                   SPACE(10) AS Size4,
                   SPACE(10) AS Size5,
                   SPACE(10) AS Size6,
                   SPACE(10) AS Size7,
                   SPACE(10) AS Size8,
                   SPACE(10) AS Size9,
                   SPACE(10) AS Size10,
                   SPACE(10) AS Size11,
                   SPACE(10) AS Size12,
                   SPACE(10) AS Size13,
                   SPACE(10) AS Size14,
                   SPACE(10) AS Size15,
                   SPACE(10) AS Size16,
                   SPACE(10) AS Size17,
                   SPACE(10) AS Size18,
                   SPACE(10) AS Size19,
                   SPACE(10) AS Size20,
                   SPACE(10) AS Size21,
                   SPACE(10) AS Size22,
                   SPACE(10) AS Size23,
                   SPACE(10) AS Size24,
                   0 AS Qty1,
                   0 AS Qty2,
                   0 AS Qty3,
                   0 AS Qty4,
                   0 AS Qty5,
                   0 AS Qty6,
                   0 AS Qty7,
                   0 AS Qty8,
                   0 AS Qty9,
                   0 AS Qty10,
                   0 AS Qty11,
                   0 AS Qty12,
                   0 AS Qty13,
                   0 AS Qty14,
                   0 AS Qty15,
                   0 AS Qty16,
                   0 AS Qty17,
                   0 AS Qty18,
                   0 AS Qty19,
                   0 AS Qty20,
                   0 AS Qty21,
                   0 AS Qty22,
                   0 AS Qty23,
                   0 AS Qty24,
                   CountSKU
   --INTO #TEMP_RECEIPT07_2
   FROM #TEMP_RECEIPT07 t
   
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Externpokey, ExternOrderkey, CaseID, Material, DESCR, SIZE, Qty
   FROM #TEMP_RECEIPT07_2
   
   OPEN CUR_LOOP 
   	
   FETCH NEXT FROM CUR_LOOP INTO @c_Externpokey, @c_ExternOrderkey, @c_CaseID, @c_BUSR10a, @c_DESCR, @c_BUSR10b, @c_Qty
   
   WHILE @@FETCH_STATUS <> - 1
   BEGIN
      SET @c_Size1  = ''
      SET @c_Size2  = ''
      SET @c_Size3  = ''
      SET @c_Size4  = ''
      SET @c_Size5  = ''
      SET @c_Size6  = ''
      SET @c_Size7  = ''
      SET @c_Size8  = ''
      SET @c_Size9  = ''
      SET @c_Size10 = ''
      SET @c_Size11 = ''
      SET @c_Size12 = ''
      SET @c_Size13 = ''
      SET @c_Size14 = ''
      SET @c_Size15 = ''
      SET @c_Size16 = ''
      SET @c_Size17 = ''
      SET @c_Size18 = ''
      SET @c_Size19 = ''
      SET @c_Size20 = ''
      SET @c_Size21 = ''
      SET @c_Size22 = ''
      SET @c_Size23 = ''
      SET @c_Size24 = ''
      
      SET @n_Qty1  = 0
      SET @n_Qty2  = 0
      SET @n_Qty3  = 0
      SET @n_Qty4  = 0
      SET @n_Qty5  = 0
      SET @n_Qty6  = 0
      SET @n_Qty7  = 0
      SET @n_Qty8  = 0
      SET @n_Qty9  = 0
      SET @n_Qty10 = 0
      SET @n_Qty11 = 0
      SET @n_Qty12 = 0
      SET @n_Qty13 = 0
      SET @n_Qty14 = 0
      SET @n_Qty15 = 0
      SET @n_Qty16 = 0
      SET @n_Qty17 = 0
      SET @n_Qty18 = 0
      SET @n_Qty19 = 0
      SET @n_Qty20 = 0
      SET @n_Qty21 = 0
      SET @n_Qty22 = 0
      SET @n_Qty23 = 0
      SET @n_Qty24 = 0
      
      IF ISNULL(@c_BUSR10b,'') = '' SET @c_BUSR10b = '|'
      IF ISNULL(@c_Qty,'') = ''  SET @c_Qty  = '|'
      
      DECLARE CUR_LOOP2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SeqNo, ColValue FROM dbo.fnc_delimsplit ('|',@c_BUSR10b) 
      
      OPEN CUR_LOOP2
      
      FETCH NEXT FROM CUR_LOOP2 INTO @c_SeqNo, @c_ColValue
      
      WHILE @@FETCH_STATUS <> - 1
      BEGIN 
      	IF @c_SeqNo = '1'
      	   SET @c_Size1 = @c_ColValue
      	ELSE IF @c_SeqNo = '2'
      	   SET @c_Size2 = @c_ColValue
      	ELSE IF @c_SeqNo = '3'
      	   SET @c_Size3 = @c_ColValue
      	ELSE IF @c_SeqNo = '4'
      	   SET @c_Size4 = @c_ColValue
      	ELSE IF @c_SeqNo = '5'
      	   SET @c_Size5 = @c_ColValue
      	ELSE IF @c_SeqNo = '6'
      	   SET @c_Size6 = @c_ColValue
      	ELSE IF @c_SeqNo = '7'
      	   SET @c_Size7 = @c_ColValue
      	ELSE IF @c_SeqNo = '8'
      	   SET @c_Size8 = @c_ColValue
      	ELSE IF @c_SeqNo = '9'
      	   SET @c_Size9 = @c_ColValue
      	ELSE IF @c_SeqNo = '10'
      	   SET @c_Size10 = @c_ColValue
      	ELSE IF @c_SeqNo = '11'
      	   SET @c_Size11 = @c_ColValue
      	ELSE IF @c_SeqNo = '12'
      	   SET @c_Size12 = @c_ColValue
      	ELSE IF @c_SeqNo = '13'
      	   SET @c_Size13 = @c_ColValue
      	ELSE IF @c_SeqNo = '14'
      	   SET @c_Size14 = @c_ColValue
      	ELSE IF @c_SeqNo = '15'
      	   SET @c_Size15 = @c_ColValue
      	ELSE IF @c_SeqNo = '16'
      	   SET @c_Size16 = @c_ColValue
      	ELSE IF @c_SeqNo = '17'
      	   SET @c_Size17 = @c_ColValue
      	ELSE IF @c_SeqNo = '18'
      	   SET @c_Size18 = @c_ColValue
      	ELSE IF @c_SeqNo = '19'
      	   SET @c_Size19 = @c_ColValue
      	ELSE IF @c_SeqNo = '20'
      	   SET @c_Size20 = @c_ColValue
      	ELSE IF @c_SeqNo = '21'
      	   SET @c_Size21 = @c_ColValue
      	ELSE IF @c_SeqNo = '22'
      	   SET @c_Size22 = @c_ColValue
      	ELSE IF @c_SeqNo = '23'
      	   SET @c_Size23 = @c_ColValue
      	ELSE IF @c_SeqNo = '24'
      	   SET @c_Size24 = @c_ColValue
 
      	FETCH NEXT FROM CUR_LOOP2 INTO @c_SeqNo, @c_ColValue
      END
      CLOSE CUR_LOOP2
      DEALLOCATE CUR_LOOP2
      
      DECLARE CUR_LOOP3 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SeqNo, ColValue FROM dbo.fnc_delimsplit ('|',@c_Qty) 
      
      OPEN CUR_LOOP3
      
      FETCH NEXT FROM CUR_LOOP3 INTO @c_SeqNo, @c_ColValue
      
      WHILE @@FETCH_STATUS <> - 1
      BEGIN
      	IF @c_SeqNo = '1'
      	   SET @n_Qty1 = @c_ColValue
      	ELSE IF @c_SeqNo = '2'
      	   SET @n_Qty2 = @c_ColValue
      	ELSE IF @c_SeqNo = '3'
      	   SET @n_Qty3 = @c_ColValue
      	ELSE IF @c_SeqNo = '4'
      	   SET @n_Qty4 = @c_ColValue
      	ELSE IF @c_SeqNo = '5'
      	   SET @n_Qty5 = @c_ColValue
      	ELSE IF @c_SeqNo = '6'
      	   SET @n_Qty6 = @c_ColValue
      	ELSE IF @c_SeqNo = '7'
      	   SET @n_Qty7 = @c_ColValue
      	ELSE IF @c_SeqNo = '8'
      	   SET @n_Qty8 = @c_ColValue
      	ELSE IF @c_SeqNo = '9'
      	   SET @n_Qty9 = @c_ColValue
      	ELSE IF @c_SeqNo = '10'
      	   SET @n_Qty10 = @c_ColValue
      	ELSE IF @c_SeqNo = '11'
      	   SET @n_Qty11 = @c_ColValue
      	ELSE IF @c_SeqNo = '12'
      	   SET @n_Qty12 = @c_ColValue
      	ELSE IF @c_SeqNo = '13'
      	   SET @n_Qty13 = @c_ColValue
      	ELSE IF @c_SeqNo = '14'
      	   SET @n_Qty14 = @c_ColValue
      	ELSE IF @c_SeqNo = '15'
      	   SET @n_Qty15 = @c_ColValue
      	ELSE IF @c_SeqNo = '16'
      	   SET @n_Qty16 = @c_ColValue
      	ELSE IF @c_SeqNo = '17'
      	   SET @n_Qty17 = @c_ColValue
      	ELSE IF @c_SeqNo = '18'
      	   SET @n_Qty18 = @c_ColValue
      	ELSE IF @c_SeqNo = '19'
      	   SET @n_Qty19 = @c_ColValue
      	ELSE IF @c_SeqNo = '20'
      	   SET @n_Qty20 = @c_ColValue
      	ELSE IF @c_SeqNo = '21'
      	   SET @n_Qty21 = @c_ColValue
      	ELSE IF @c_SeqNo = '22'
      	   SET @n_Qty22 = @c_ColValue
      	ELSE IF @c_SeqNo = '23'
      	   SET @n_Qty23 = @c_ColValue
      	ELSE IF @c_SeqNo = '24'
      	   SET @n_Qty24 = @c_ColValue
      	    
      	FETCH NEXT FROM CUR_LOOP3 INTO @c_SeqNo, @c_ColValue
      END
      CLOSE CUR_LOOP3
      DEALLOCATE CUR_LOOP3

      UPDATE #TEMP_RECEIPT07_2
      SET Size1  = @c_Size1 
        , Size2  = @c_Size2 
        , Size3  = @c_Size3 
        , Size4  = @c_Size4 
        , Size5  = @c_Size5 
        , Size6  = @c_Size6 
        , Size7  = @c_Size7 
        , Size8  = @c_Size8 
        , Size9  = @c_Size9 
        , Size10 = @c_Size10
        , Size11 = @c_Size11
        , Size12 = @c_Size12
        , Size13 = @c_Size13
        , Size14 = @c_Size14
        , Size15 = @c_Size15
        , Size16 = @c_Size16
        , Size17 = @c_Size17
        , Size18 = @c_Size18
        , Size19 = @c_Size19
        , Size20 = @c_Size20
        , Size21 = @c_Size21
        , Size22 = @c_Size22
        , Size23 = @c_Size23
        , Size24 = @c_Size24
        , Qty1   = @n_Qty1 
        , Qty2   = @n_Qty2 
        , Qty3   = @n_Qty3 
        , Qty4   = @n_Qty4 
        , Qty5   = @n_Qty5 
        , Qty6   = @n_Qty6 
        , Qty7   = @n_Qty7 
        , Qty8   = @n_Qty8 
        , Qty9   = @n_Qty9 
        , Qty10  = @n_Qty10    
        , Qty11  = @n_Qty11  
        , Qty12  = @n_Qty12  
        , Qty13  = @n_Qty13  
        , Qty14  = @n_Qty14  
        , Qty15  = @n_Qty15  
        , Qty16  = @n_Qty16  
        , Qty17  = @n_Qty17  
        , Qty18  = @n_Qty18  
        , Qty19  = @n_Qty19  
        , Qty20  = @n_Qty20  
        , Qty21  = @n_Qty21  
        , Qty22  = @n_Qty22  
        , Qty23  = @n_Qty23  
        , Qty24  = @n_Qty24  
      WHERE Externpokey = @c_Externpokey
      AND ExternOrderkey = @c_ExternOrderkey
      AND CaseID = @c_CaseID
      AND Material = @c_BUSR10a
      AND Descr = @c_DESCR
      
   	FETCH NEXT FROM CUR_LOOP INTO @c_Externpokey, @c_ExternOrderkey, @c_CaseID, @c_BUSR10a, @c_DESCR, @c_BUSR10b, @c_Qty
   END
   
   DECLARE CUR_FINAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Consigneekey, Externpokey, ExternOrderkey, MIN(Material) AS Material, CaseID--, DESCR
      FROM #TEMP_RECEIPT07_2
      GROUP BY Consigneekey, Externpokey, ExternOrderkey, CaseID--, DESCR
      ORDER BY Consigneekey, Externpokey, ExternOrderkey, MIN(Material), CaseID--, DESCR
   
   OPEN CUR_FINAL
   
   FETCH NEXT FROM CUR_FINAL INTO @c_GetConsigneekey, @c_GetExternpokey, @c_GetExternOrderkey, @c_GetItemClass, @c_GetCaseID  
       
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	INSERT INTO #TEMP_RECEIPT07_Final (Logo, Company, Address1, Address2, Address3, Address4, VAT, Consigneekey  
   		                              , C_Company, C_Address1, C_Address2, C_Address3, C_Address4, BillToKey, B_Company     
   		                              , Shipdate, Userdefine10, MBOLKey, OTMShipmentID, Userdefine04, Externpokey, ExternOrderkey
   		                              , CaseID, Material, DESCR, SIZE, qty, uom           
   		                              , Size1, Size2, Size3, Size4, Size5, Size6, Size7, Size8, Size9, Size10     
   		                              , Size11, Size12, Size13, Size14, Size15, Size16, Size17, Size18, Size19, Size20  
   		                              , Size21, Size22, Size23, Size24   
   		                              , Qty1, Qty2, Qty3, Qty4, Qty5, Qty6, Qty7, Qty8, Qty9, Qty10
   		                              , Qty11, Qty12, Qty13, Qty14, Qty15, Qty16, Qty17, Qty18, Qty19, Qty20
   		                              , Qty21, Qty22, Qty23, Qty24
   		                              , Countsku)
   	SELECT Logo, Company, Address1, Address2, Address3, Address4, VAT, Consigneekey  
   		  , C_Company, C_Address1, C_Address2, C_Address3, C_Address4, BillToKey, B_Company     
   		  , Shipdate, Userdefine10, MBOLKey, OTMShipmentID, Userdefine04, Externpokey, ExternOrderkey
   		  , CaseID, Material, DESCR, SIZE, qty, uom           
   		  , Size1, Size2, Size3, Size4, Size5, Size6, Size7, Size8, Size9, Size10     
   		  , Size11, Size12, Size13, Size14, Size15, Size16, Size17, Size18, Size19, Size20  
   		  , Size21, Size22, Size23, Size24   
   		  , Qty1, Qty2, Qty3, Qty4, Qty5, Qty6, Qty7, Qty8, Qty9, Qty10
   		  , Qty11, Qty12, Qty13, Qty14, Qty15, Qty16, Qty17, Qty18, Qty19, Qty20
   		  , Qty21, Qty22, Qty23, Qty24
   		  , Countsku
   	FROM #TEMP_RECEIPT07_2 AS tr
   	WHERE tr.Consigneekey = @c_GetConsigneekey 
   	AND tr.Externpokey = @c_GetExternpokey 
   	AND tr.ExternOrderkey = @c_GetExternOrderkey 
   	--AND tr.Material = @c_GetItemClass 
   	AND tr.CaseID = @c_GetCaseID
   	ORDER BY Material, CaseID, DESCR
   	
   	FETCH NEXT FROM CUR_FINAL INTO @c_GetConsigneekey, @c_GetExternpokey, @c_GetExternOrderkey, @c_GetItemClass, @c_GetCaseID   
   END   
   
   IF @c_Type = 'S1'
   BEGIN
      SELECT Logo, Company, Address1, Address2, Address3, Address4, VAT, Consigneekey  
           , C_Company, C_Address1, C_Address2, C_Address3, C_Address4, BillToKey, B_Company     
           , Shipdate, Userdefine10, MBOLKey, OTMShipmentID, Userdefine04, Externpokey, ExternOrderkey
           , CaseID, Material, DESCR, SIZE, qty, uom           
           , Size1, Size2, Size3, Size4, Size5, Size6, Size7, Size8, Size9, Size10     
   		  , Size11, Size12, Size13, Size14, Size15, Size16, Size17, Size18, Size19, Size20  
   		  , Size21, Size22, Size23, Size24   
   		  , Qty1, Qty2, Qty3, Qty4, Qty5, Qty6, Qty7, Qty8, Qty9, Qty10
   		  , Qty11, Qty12, Qty13, Qty14, Qty15, Qty16, Qty17, Qty18, Qty19, Qty20
   		  , Qty21, Qty22, Qty23, Qty24
   		  , Countsku 
      FROM #TEMP_RECEIPT07_Final
      WHERE Consigneekey = @c_ShipTo
   END
   ELSE IF @c_Type = 'S2'
   BEGIN
   	SELECT COUNT(DISTINCT Userdefine10) AS CountUserdefine10,
   	       COUNT(DISTINCT Externpokey) AS CountExternpokey,
   	       COUNT(DISTINCT ExternOrderkey) AS CountExternOrderkey,
   	       COUNT(DISTINCT CaseID) AS CountCaseID,
   	       COUNT(DISTINCT Material) AS CountMaterial,
   	       MAX(Countsku) AS CountSKU,
   	       SUM(Qty1 + Qty2 + Qty3 + Qty4 + Qty5 + Qty6 + Qty7 + Qty8 + Qty9 + Qty10 +
   	           Qty11 + Qty12 + Qty13 + Qty14 + Qty15 + Qty16 + Qty17 + Qty18 + Qty19 + Qty20 +
   	           Qty21 + Qty22 + Qty23 + Qty24) AS SumQty
   	FROM #TEMP_RECEIPT07_Final
   	WHERE Consigneekey = @c_ShipTo
   END
                                        
QUIT_SP:                                    
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN                                    
      CLOSE CUR_LOOP                        
      DEALLOCATE CUR_LOOP                   
   END                                      
                                            
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP2') IN (0 , 1)
   BEGIN                                    
      CLOSE CUR_LOOP2                       
      DEALLOCATE CUR_LOOP2                  
   END                                      
                                            
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP3') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP3
      DEALLOCATE CUR_LOOP3   
   END
   
   IF CURSOR_STATUS('LOCAL', 'CUR_Final') IN (0 , 1)
   BEGIN
      CLOSE CUR_Final
      DEALLOCATE CUR_Final   
   END
   
   IF CURSOR_STATUS('LOCAL', 'CUR_Consignee') IN (0 , 1)
   BEGIN
      CLOSE CUR_Consignee
      DEALLOCATE CUR_Consignee   
   END

   IF OBJECT_ID('tempdb..#TEMP_RECEIPT07') IS NOT NULL
      DROP TABLE #TEMP_RECEIPT07
      
   IF OBJECT_ID('tempdb..#TEMP_RECEIPT07_2') IS NOT NULL
      DROP TABLE #TEMP_RECEIPT07_2
      
   IF OBJECT_ID('tempdb..#TEMP_RECEIPT07_Final') IS NOT NULL
      DROP TABLE #TEMP_RECEIPT07_Final
         
   IF OBJECT_ID('tempdb..#TMP_CONKey') IS NOT NULL
      DROP TABLE #TMP_CONKey
      
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'isp_delivery_receipt07'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END 
END

GO