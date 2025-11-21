SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store Procedure: isp_PackListBySku10                                       */  
/* Creation Date: 12-Jan-2016                                                 */  
/* Copyright: IDS                                                             */  
/* Written by: CSCHONG (Copy from nsp_PackListBySku03_chs)                    */  
/*                                                                            */  
/* Purpose:  SOS#360711 -Converse - CR for RCM Packing list report of CN      */  
/*                                                                            */  
/* Called By: Powerbuilder                                                    */  
/*                                                                            */  
/* PVCS Version: 1.1                                                          */  
/*                                                                            */  
/* Version: 5.4                                                               */  
/*                                                                            */  
/* Data Modifications:                                                        */  
/*                                                                            */  
/* Updates:                                                                   */  
/* Date         Author    Ver.  Purposes                                      */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/******************************************************************************/  
  
CREATE PROC [dbo].[isp_PackListBySku10] (@c_PickSlipNo NVARCHAR(30))  
AS  
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
  
BEGIN
	DECLARE @n_Cnt                INT,
	        @n_PosStart           INT,
	        @n_PosEnd             INT,
	        @n_DashPos            INT,
	        @c_ExecSQLStmt        NVARCHAR(MAX),
	        @c_ExecArguments      NVARCHAR(MAX),
	        @c_ExternOrderkey     NVARCHAR(50),  --tlting_ext
	        @c_OrderkeyStart      NVARCHAR(10),
	        @c_OrderkeyEnd        NVARCHAR(10),
	        @c_ReprintFlag        NVARCHAR(1),
	        @n_CartonNo           INT,
	        @c_Storerkey          NVARCHAR(15),
	        @c_Style              NVARCHAR(20),
	        @c_Color              NVARCHAR(10),
	        @c_Size               NVARCHAR(5),
	        @n_Qty                INT,
	        @c_colorsize_busr67   NVARCHAR(10), --NJOW01
	        @n_Err                INT,  --NJOW01
	        @c_ErrMsg             NVARCHAR(250),  --NJOW01
	        @b_Success            INT  --NJOW01
	
	SET @n_Cnt = 1  
	SET @n_PosStart = 0
	SET @n_PosEnd = 0
	SET @n_DashPos = 0
	
	SET @c_ExecSQLStmt = ''  
	SET @c_ExecArguments = ''
	
	SET @n_CartonNo = 0
	SET @c_Storerkey = ''
	SET @c_Style = '' 
	SET @c_Color = '' 
	SET @c_Size = '' 
	SET @n_Qty = 0
	
	CREATE TABLE #TempNPPL
	(
		OrderKey           NVARCHAR(30),
		ExternOrderkey     NVARCHAR(50),  --tlting_ext
		Storerkey          NVARCHAR(15),
		ST_Company         NVARCHAR(45),
		ReprintFlag        NVARCHAR(1),
		PickSlipNo         NVARCHAR(20),
		Company            NVARCHAR(80),
		Address1           NVARCHAR(45),
		Address2           NVARCHAR(45),
		Address3           NVARCHAR(45),
		Address4           NVARCHAR(45),
		City               NVARCHAR(45),
		STATE              NVARCHAR(45),
		Country            NVARCHAR(45),
		Contact1           NVARCHAR(30),
		Phone1             NVARCHAR(20),
		Style              NVARCHAR(20),
		Color              NVARCHAR(10),
		CartonNo           INT,
		SizeCOL1           NVARCHAR(5) NULL,
		QtyCOL1            INT NULL,
		SizeCOL2           NVARCHAR(5) NULL,
		QtyCOL2            INT NULL,
		SizeCOL3           NVARCHAR(5) NULL,
		QtyCOL3            INT NULL,
		SizeCOL4           NVARCHAR(5) NULL,
		QtyCOL4            INT NULL,
		SizeCOL5           NVARCHAR(5) NULL,
		QtyCOL5            INT NULL,
		SizeCOL6           NVARCHAR(5) NULL,
		QtyCOL6            INT NULL,
		SizeCOL7           NVARCHAR(5) NULL,
		QtyCOL7            INT NULL,
		SizeCOL8           NVARCHAR(5) NULL,
		QtyCOL8            INT NULL,
		SizeCOL9           NVARCHAR(5) NULL,
		QtyCOL9            INT NULL,
		SizeCOL10          NVARCHAR(5) NULL,
		QtyCOL10           INT NULL,
		SizeCOL11          NVARCHAR(5) NULL,
		QtyCOL11           INT NULL,
		SizeCOL12          NVARCHAR(5) NULL,
		QtyCOL12           INT NULL,
		SizeCOL13          NVARCHAR(5) NULL,
		QtyCOL13           INT NULL,
		SizeCOL14          NVARCHAR(5) NULL,
		QtyCOL14           INT NULL,
		SizeCOL15          NVARCHAR(5) NULL,
		QtyCOL15           INT NULL,
		SizeCOL16          NVARCHAR(5) NULL,
		QtyCOL16           INT NULL,
		SizeCOL17          NVARCHAR(5) NULL,
		QtyCOL17           INT NULL,
		SizeCOL18          NVARCHAR(5) NULL,
		QtyCOL18           INT NULL,
		SizeCOL19          NVARCHAR(5) NULL,
		QtyCOL19           INT NULL,
		SizeCOL20          NVARCHAR(5) NULL,
		QtyCOL20           INT NULL,
		SizeCOL21          NVARCHAR(5) NULL,
		QtyCOL21           INT NULL,
		SizeCOL22          NVARCHAR(5) NULL,
		QtyCOL22           INT NULL,
		SizeCOL23          NVARCHAR(5) NULL,
		QtyCOL23           INT NULL,
		SizeCOL24          NVARCHAR(5) NULL,
		QtyCOL24           INT NULL,
		SizeCOL25          NVARCHAR(5) NULL,
		QtyCOL25           INT NULL,
		SizeCOL26          NVARCHAR(5) NULL,
		QtyCOL26           INT NULL,
		SizeCOL27          NVARCHAR(5) NULL,
		QtyCOL27           INT NULL,
		SizeCOL28          NVARCHAR(5) NULL,
		QtyCOL28           INT NULL,
		SizeCOL29          NVARCHAR(5) NULL,
		QtyCOL29           INT NULL,
		SizeCOL30          NVARCHAR(5) NULL,
		QtyCOL30           INT NULL,
		TotalCarton        INT NULL,
		BuyerPO            NVARCHAR(20) NULL,
      MaterialID         NVARCHAR(18) NULL 
	)                                               
	
	--NJOW01
	SELECT @c_storerkey = Storerkey
	FROM PACKHEADER (NOLOCK)
	WHERE Pickslipno = @c_Pickslipno
	
	EXECUTE nspGetRight
          NULL              -- Facility
        , @c_StorerKey             -- Storer
        , NULL                     -- No Sku in this Case
        , 'PICKLISTBYSKU03CHS_BUSR67'       -- ConfigKey
        , @b_success               OUTPUT 
        , @c_colorsize_busr67      OUTPUT  
        , @n_err                   OUTPUT  
        , @c_errmsg                OUTPUT  
		
	INSERT INTO #TempNPPL
	  (
	    OrderKey,
	    ExternOrderKey,
	    Storerkey,
	    ST_Company,
	    ReprintFlag,
	    PickSlipNo,
	    Company,
	    address1,
	    address2,
	    address3,
	    address4,
	    City,
	    STATE,
	    Country,
	    Contact1,
	    Phone1,
	    BuyerPO, 	    
	    CartonNo,
	    Style,
	    Color,
       MaterialID 
	  )
	SELECT DISTINCT
	       ISNULL(RTRIM(O.Orderkey), '')  AS OrderKey,
	       ISNULL(RTRIM(O.ExternOrderKey), '') AS ExternOrderKey,
	       ISNULL(RTRIM(O.Storerkey), '') AS Storerkey,
	       ISNULL(RTRIM(ST.Company), '')  AS ST_Company,
	       '' AS                             ReprintFlag,
	       ISNULL(RTRIM(PH.PickSlipNo), '') AS PickSlipNo,
	       CASE 
	            WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Company), '')
	            ELSE ISNULL(RTRIM(C.Company), '')
	       END 
	       + '(' + ISNULL(RTRIM(O.BillToKey), '') + '-' + ISNULL(RTRIM(O.ConsigneeKey), '') 
	       + ')' AS                          Company,
	       CASE 
	            WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Address1), '')
	            ELSE ISNULL(RTRIM(C.Address1), '')
	       END                            AS Address1,
	       CASE 
	            WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Address2), '')
	            ELSE ISNULL(RTRIM(C.Address2), '')
	       END                            AS Address2,
	       CASE 
	            WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Address3), '')
	            ELSE ISNULL(RTRIM(C.Address3), '')
	       END                            AS Address3,
	       CASE 
	            WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Address4), '')
	            ELSE ISNULL(RTRIM(C.Address4), '')
	       END                            AS Address4,
	       CASE 
	            WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_City), '')
	            ELSE ISNULL(RTRIM(C.City), '')
	       END                            AS City,
	       CASE 
	            WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_State), '')
	            ELSE ISNULL(RTRIM(C.State), '')
	       END                            AS STATE,
	       CASE 
	            WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Country), '')
	            ELSE ISNULL(RTRIM(C.Country), '')
	       END                            AS Country,
	       CASE 
	            WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Contact1), '')
	            ELSE ISNULL(RTRIM(C.Contact1), '')
	       END                            AS Contact1,
	       CASE 
	            WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Phone1), '')
	            ELSE ISNULL(RTRIM(C.Phone1), '')
	       END                            AS Phone1,
	       ISNULL(RTRIM(O.BuyerPO), '')   AS BuyerPO, --(Wan01)
	       ISNULL(PD.CartonNo, 0)         AS CartonNo,
	       ISNULL(RTRIM(S.Style), '')     AS Style,
	       CASE WHEN ISNULL(@c_colorsize_busr67,'') = '1' THEN  --NJOW01
	              LEFT(ISNULL(S.Busr6,''),10)
	            ELSE
	              ISNULL(RTRIM(S.Color),'') END AS Color,
          ORDDET.Userdefine09
	FROM   ORDERS O WITH (NOLOCK)
	       JOIN STORER ST WITH (NOLOCK)
	            ON  (ST.StorerKey = O.Storerkey)
	       JOIN Packheader PH WITH (NOLOCK)
	            ON  (O.Orderkey = PH.Orderkey AND O.Storerkey = PH.Storerkey)
	       JOIN PackDetail PD WITH (NOLOCK)
	            ON  (PD.PickSlipNo = PH.PickSlipNo)
          JOIN   ORDERDETAIL ORDDET WITH (NOLOCK) 
               ON O.Orderkey = ORDDET.Orderkey AND ORDDET.Sku = PD.SKU
	       JOIN SKU S WITH (NOLOCK)
	            ON  (S.Storerkey = PD.Storerkey)
	            AND (S.Sku = PD.Sku)
	       LEFT JOIN STORER C WITH (NOLOCK)
	            ON  (
	                    C.StorerKey = ISNULL(RTRIM(O.BillToKey), '') + ISNULL(RTRIM(O.ConsigneeKey), '')
	                )
	WHERE  PH.PickSlipNo = @c_PickSlipNo 
	
	DECLARE PACK_CUR CURSOR FAST_FORWARD READ_ONLY 
	FOR
	    SELECT CartonNo,
	           Storerkey,
	           Style,
	           Color
	    FROM   #TempNPPL
	
	OPEN PACK_CUR 
	
	FETCH NEXT FROM PACK_CUR INTO @n_CartonNo
	, @c_Storerkey
	, @c_Style
	, @c_Color
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
	    SET @n_Cnt = 1 
	    IF ISNULL(@c_colorsize_busr67,'') = '1'  --NJOW01
	    BEGIN
	       DECLARE SIZE_CUR CURSOR FAST_FORWARD READ_ONLY 
	       FOR
	           SELECT CASE WHEN CHARINDEX('|',S.Busr7) > 0 THEN
	                            LEFT(S.BUSR7, CHARINDEX('|',S.BUSR7)-1)
	                       ELSE LEFT(ISNULL(S.Busr7,''),4) END AS Size,
	                  ISNULL(PD.Qty, 0)
	           FROM   PackDetail PD WITH (NOLOCK)
	                  JOIN SKU S WITH (NOLOCK)
	                       ON  (S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU)
	           WHERE  PD.PickSlipNo = @c_PickSlipNo
	                  AND PD.CartonNo = @n_CartonNo
	                  AND S.Style = @c_Style
	                  AND LEFT(ISNULL(S.Busr6,''),10) = @c_Color
	           ORDER BY
	                  1
	    END
	    ELSE
	    BEGIN
	       DECLARE SIZE_CUR CURSOR FAST_FORWARD READ_ONLY 
	       FOR
              SELECT CASE WHEN ISNULL(C.short,'')='Y' THEN                                                    
                     CASE WHEN S.measurement IN ('','U') THEN SUBSTRING(ISNULL(RTRIM(S.Size), ''), 1, 4)    
                                                           ELSE ISNULL(S.measurement,'') END               
                     ELSE S.Size END [Size] ,                                                             
	           --SELECT SUBSTRING(ISNULL(RTRIM(S.Size), ''), 1, 4) SIZE,
	                  ISNULL(PD.Qty, 0)
	           FROM   PackDetail PD WITH (NOLOCK)
	                  JOIN SKU S WITH (NOLOCK)
	                       ON  (S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU)
              LEFT JOIN CODELKUP C WITH (nolock) ON C.storerkey= PD.Storerkey             
               AND listname = 'REPORTCFG' and code ='GetSkuMeasurement'                             
	            AND long='r_dw_packing_list_by_sku10'                                           
	           WHERE  PD.PickSlipNo = @c_PickSlipNo
	                  AND PD.CartonNo = @n_CartonNo
	                  AND S.Style = @c_Style
	                  AND S.Color = @c_Color
	           ORDER BY
	                  SUBSTRING(s.size, 1, 4)
	    END
	    OPEN SIZE_CUR 
	    
	    FETCH NEXT FROM SIZE_CUR INTO @c_Size, @n_Qty 
	    
	    WHILE @@FETCH_STATUS = 0
	    BEGIN
	        SET @c_ExecSQLStmt = N'UPDATE #TempNPPL SET SizeCOL' + RTRIM(CONVERT(VARCHAR(2), @n_Cnt))
	            + '=N''' + RTRIM(@c_Size) + '''' 
	            + ',QtyCOL' + RTRIM(CONVERT(VARCHAR(2), @n_Cnt)) + '=@n_qty' 
	            + ' WHERE PickSlipNo = @c_PickSlipNo' 
	            + ' AND CartonNo = @n_CartonNo' 
	            + ' AND Style = @c_Style'
	            + ' AND Color = @c_Color'
	        
	        SET @c_ExecArguments = N'@c_PickSlipNo NVARCHAR(10)' 
	            + ',@n_CartonNo   INT' 
	            + ',@c_Style      NVARCHAR(20)' 
	            + ',@c_Color      NVARCHAR(10)' 
	            + ',@n_Qty        INT'            
	        
	        EXEC sp_ExecuteSql @c_ExecSQLStmt,
	             @c_ExecArguments,
	             @c_PickSlipNo,
	             @n_CartonNo,
	             @c_Style,
	             @c_Color,
	             @n_Qty   
	        
	        SET @n_Cnt = @n_Cnt + 1 
	        
	        FETCH NEXT FROM SIZE_CUR INTO @c_Size, @n_Qty
	    END -- SIZE_CUR WHILE loop   
	    
	    CLOSE SIZE_CUR 
	    DEALLOCATE SIZE_CUR 
	    
	    FETCH NEXT FROM PACK_CUR INTO @n_CartonNo
	    , @c_Storerkey
	    , @c_Style
	    , @c_Color
	END -- PACK_CUR WHILE loop  
	
	CLOSE PACK_CUR 
	DEALLOCATE PACK_CUR  
	
	UPDATE #TempNPPL
	SET    TotalCarton = PD.TotCarton
	FROM   #TempNPPL TP
	       JOIN (
	                SELECT PickSlipNo,
	                       COUNT(DISTINCT CartonNo) AS TotCarton
	                FROM   PackDetail WITH (NOLOCK)
	                WHERE  pickslipno = @c_PickSlipNo
	                GROUP BY
	                       PickSlipNo
	            ) AS PD
	            ON  (PD.PickSlipNo = TP.PickSlipNo) 
	
	SELECT OrderKey,
	       ISNULL(RTRIM(ExternOrderKey), ''),
	       ISNULL(RTRIM(Storerkey), ''),
	       ISNULL(RTRIM(ST_Company), ''),
	       ISNULL(RTRIM(PickSlipNo), ''),
	       ISNULL(RTRIM(Company), ''),
	       ISNULL(RTRIM(address1), ''),
	       ISNULL(RTRIM(address2), ''),
	       ISNULL(RTRIM(address3), ''),
	       ISNULL(RTRIM(address4), ''),
	       ISNULL(RTRIM(City), ''),
	       ISNULL(RTRIM(STATE), ''),
	       ISNULL(RTRIM(Country), ''),
	       ISNULL(RTRIM(Contact1), ''),
	       ISNULL(RTRIM(phone1), ''),
	       ISNULL(CartonNo, 0),
	       ISNULL(RTRIM(Style), ''),
	       ISNULL(RTRIM(Color), ''),
	       ISNULL(RTRIM(SizeCOL1), ''),
	       ISNULL(QtyCOL1, 0),
	       ISNULL(RTRIM(SizeCOL2), ''),
	       ISNULL(QtyCOL2, 0),
	       ISNULL(RTRIM(SizeCOL3), ''),
	       ISNULL(QtyCOL3, 0),
	       ISNULL(RTRIM(SizeCOL4), ''),
	       ISNULL(QtyCOL4, 0),
	       ISNULL(RTRIM(SizeCOL5), ''),
	       ISNULL(QtyCOL5, 0),
	       ISNULL(RTRIM(SizeCOL6), ''),
	       ISNULL(QtyCOL6, 0),
	       ISNULL(RTRIM(SizeCOL7), ''),
	       ISNULL(QtyCOL7, 0),
	       ISNULL(RTRIM(SizeCOL8), ''),
	       ISNULL(QtyCOL8, 0),
	       ISNULL(RTRIM(SizeCOL9), ''),
	       ISNULL(QtyCOL9, 0),
	       ISNULL(RTRIM(SizeCOL10), ''),
	       ISNULL(QtyCOL10, 0),
	       ISNULL(RTRIM(SizeCOL11), ''),
	       ISNULL(QtyCOL11, 0),
	       ISNULL(RTRIM(SizeCOL12), ''),
	       ISNULL(QtyCOL12, 0),
	       ISNULL(RTRIM(SizeCOL13), ''),
	       ISNULL(QtyCOL13, 0),
	       ISNULL(RTRIM(SizeCOL14), ''),
	       ISNULL(QtyCOL14, 0),
	       ISNULL(RTRIM(SizeCOL15), ''),
	       ISNULL(QtyCOL15, 0),
	       ISNULL(RTRIM(SizeCOL16), ''),
	       ISNULL(QtyCOL16, 0),
	       ISNULL(RTRIM(SizeCOL17), ''),
	       ISNULL(QtyCOL17, 0),
	       ISNULL(RTRIM(SizeCOL18), ''),
	       ISNULL(QtyCOL18, 0),
	       ISNULL(RTRIM(SizeCOL19), ''),
	       ISNULL(QtyCOL19, 0),
	       ISNULL(RTRIM(SizeCOL20), ''),
	       ISNULL(QtyCOL20, 0),
	       ISNULL(RTRIM(SizeCOL21), ''),
	       ISNULL(QtyCOL21, 0),
	       ISNULL(RTRIM(SizeCOL22), ''),
	       ISNULL(QtyCOL22, 0),
	       ISNULL(RTRIM(SizeCOL23), ''),
	       ISNULL(QtyCOL23, 0),
	       ISNULL(RTRIM(SizeCOL24), ''),
	       ISNULL(QtyCOL24, 0),
	       ISNULL(RTRIM(SizeCOL25), ''),
	       ISNULL(QtyCOL25, 0),
	       ISNULL(RTRIM(SizeCOL26), ''),
	       ISNULL(QtyCOL26, 0),
	       ISNULL(RTRIM(SizeCOL27), ''),
	       ISNULL(QtyCOL27, 0),
	       ISNULL(RTRIM(SizeCOL28), ''),
	       ISNULL(QtyCOL28, 0),
	       ISNULL(RTRIM(SizeCOL29), ''),
	       ISNULL(QtyCOL29, 0),
	       ISNULL(RTRIM(SizeCOL30), ''),
	       ISNULL(QtyCOL30, 0),
	       ISNULL(TotalCarton, 0),
	       ISNULL(RTRIM(BuyerPO), ''), 
          ISNULL(MaterialID,'') as MaterialID
	FROM   #TempNPPL
	ORDER BY
	       ISNULL(RTRIM(PickSlipNo), ''),
	       ISNULL(RTRIM(Storerkey), ''),
	       ISNULL(CartonNo, 0),
	       ISNULL(RTRIM(Style), ''),
	       ISNULL(RTRIM(Color), '') 
	
	DROP TABLE #TempNPPL
END

GO