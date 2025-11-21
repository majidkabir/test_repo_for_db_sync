SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store Procedure: isp_packing_list_102                                      */  
/* Creation Date: 22-Jun-2021                                                 */  
/* Copyright: LFL                                                             */  
/* Written by: WLChooi                                                        */  
/*                                                                            */  
/* Purpose: WMS-17280 - [CN] Converse B2B packing list CR                     */  
/*          Copy from nsp_PackListBySku03_chs                                 */   
/*                                                                            */
/* Called By: r_dw_packing_list_102_                                          */  
/*                                                                            */  
/* GitLab Version: 1.0                                                        */  
/*                                                                            */  
/* Version: 5.4                                                               */  
/*                                                                            */  
/* Data Modifications:                                                        */  
/*                                                                            */  
/* Updates:                                                                   */  
/* Date         Author    Ver.  Purposes                                      */
/******************************************************************************/   
CREATE PROC [dbo].[isp_packing_list_102] (@c_Pickslipno NVARCHAR(10))  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Cnt                INT,
           @n_PosStart           INT,
           @n_PosEnd             INT,
           @n_DashPos            INT,
           @c_ExecSQLStmt        NVARCHAR(MAX),
           @c_ExecArguments      NVARCHAR(MAX),
           @c_ExternOrderkey     NVARCHAR(4000),
           @c_OrderkeyStart      NVARCHAR(10),
           @c_OrderkeyEnd        NVARCHAR(10),
           @c_ReprintFlag        NVARCHAR(1),
           @n_CartonNo           INT,
           @c_Storerkey          NVARCHAR(15),
           @c_Style              NVARCHAR(20),
           @c_Color              NVARCHAR(10),
           @c_Size               NVARCHAR(5),
           @n_Qty                INT,
           @c_colorsize_busr67   NVARCHAR(10),
           @n_Err                INT,
           @c_ErrMsg             NVARCHAR(250),
           @b_Success            INT,
           @c_BillToCsgnkey      NVARCHAR(15),
           @c_Company            NVARCHAR(100),
           @c_Address1           NVARCHAR(100),
           @c_Address2           NVARCHAR(100),
           @c_Address3           NVARCHAR(100),
           @c_Address4           NVARCHAR(100),
           @c_City               NVARCHAR(100),
           @c_STATE              NVARCHAR(100),
           @c_Country            NVARCHAR(100),
           @c_Contact1           NVARCHAR(100),
           @c_Phone1             NVARCHAR(100),
           @c_BuyerPO            NVARCHAR(50),
           @c_Orderkey           NVARCHAR(10)
   
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
      ExternOrderkey     NVARCHAR(4000),
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
      [STATE]            NVARCHAR(45),
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
      Loadkey            NVARCHAR(10)
   )                                               
   
   SELECT @c_storerkey     = MAX(OH.Storerkey)
        , @c_BillToCsgnkey = LEFT(MAX(ISNULL(RTRIM(OH.BillToKey), '')  + ISNULL(RTRIM(OH.ConsigneeKey), '')), 15)
        , @c_Orderkey      = MAX(OH.OrderKey)
   FROM PACKHEADER PH (NOLOCK)
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   WHERE PH.Pickslipno = @c_Pickslipno

   SELECT @c_Company  = CASE 
                             WHEN MAX(C.Storerkey) IS NULL THEN MAX(ISNULL(RTRIM(O.C_Company), '') )
                             ELSE MAX(ISNULL(RTRIM(C.Company), '') )
                        END 
                        + '(' + MAX(ISNULL(RTRIM(O.BillToKey), '') ) + '-' + MAX(ISNULL(RTRIM(O.ConsigneeKey), '') ) 
                        + ')'
        , @c_Address1 = CASE 
                             WHEN MAX(C.Storerkey) IS NULL THEN MAX(ISNULL(RTRIM(O.C_Address1), '') )
                             ELSE MAX(ISNULL(RTRIM(C.Address1), '') )
                        END
        , @c_Address2 = CASE 
                             WHEN MAX(C.Storerkey) IS NULL THEN MAX(ISNULL(RTRIM(O.C_Address2), '') )
                             ELSE MAX(ISNULL(RTRIM(C.Address2), '') )
                        END
        , @c_Address3 = CASE 
                             WHEN MAX(C.Storerkey) IS NULL THEN MAX(ISNULL(RTRIM(O.C_Address3), '') )
                             ELSE MAX(ISNULL(RTRIM(C.Address3), '') )
                        END
        , @c_Address4 = CASE 
                             WHEN MAX(C.Storerkey) IS NULL THEN MAX(ISNULL(RTRIM(O.C_Address4), '') )
                             ELSE MAX(ISNULL(RTRIM(C.Address4), '') )
                        END
        , @c_City     = CASE 
                             WHEN MAX(C.Storerkey) IS NULL THEN MAX(ISNULL(RTRIM(O.C_City), '') )
                             ELSE MAX(ISNULL(RTRIM(C.City), '') )
                        END
        , @c_STATE    = CASE 
                             WHEN MAX(C.Storerkey) IS NULL THEN MAX(ISNULL(RTRIM(O.C_State), '') )
                             ELSE MAX(ISNULL(RTRIM(C.[State]), '') )
                        END
        , @c_Country  = CASE 
                             WHEN MAX(C.Storerkey) IS NULL THEN MAX(ISNULL(RTRIM(O.C_Country), '') )
                             ELSE MAX(ISNULL(RTRIM(C.Country), '') )
                        END
        , @c_Contact1 = CASE 
                             WHEN MAX(C.Storerkey) IS NULL THEN MAX(ISNULL(RTRIM(O.C_Contact1), '') )
                             ELSE MAX(ISNULL(RTRIM(C.Contact1), '') )
                        END
        , @c_Phone1   = CASE 
                             WHEN MAX(C.Storerkey) IS NULL THEN MAX(ISNULL(RTRIM(O.C_Phone1), '') )
                             ELSE MAX(ISNULL(RTRIM(C.Phone1), '') )
                        END
        , @c_BuyerPO  = MAX(ISNULL(RTRIM(O.BuyerPO), ''))
   FROM ORDERS O (NOLOCK)
   OUTER APPLY (SELECT MAX(Storerkey) AS Storerkey
                     , MAX(Company)   AS Company
                     , MAX(Address1)  AS Address1
                     , MAX(Address2)  AS Address2
                     , MAX(Address3)  AS Address3
                     , MAX(Address4)  AS Address4
                     , MAX(City)      AS City
                     , MAX([State])   AS [STATE]
                     , MAX(Country)   AS Country
                     , MAX(Contact1)  AS Contact1
                     , MAX(Phone1)    AS Phone1
                FROM STORER WITH (NOLOCK) 
                WHERE StorerKey = @c_BillToCsgnkey ) AS C
   WHERE O.OrderKey = @c_Orderkey

   SELECT @c_ExternOrderkey = STUFF((SELECT DISTINCT ', ' + RTRIM(OH.ExternOrderkey) 
                                     FROM PACKHEADER PH (NOLOCK)
                                     JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.LoadKey = LPD.LoadKey
                                     JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
                                     WHERE PH.PickSlipNo = @c_Pickslipno 
                                     ORDER BY 1 
                                     FOR XML PATH('')),1,1,'' )

   EXECUTE nspGetRight
          NULL                     -- Facility
        , @c_StorerKey             -- Storer
        , NULL                     -- No Sku in this Case
        , 'PICKLIST102_BUSR67'     -- ConfigKey
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
       [STATE],
       Country,
       Contact1,
       Phone1,
       BuyerPO,  
       CartonNo,
       Style,
       Color,
       Loadkey
   )
   SELECT DISTINCT
          ''  AS OrderKey,
          @c_ExternOrderkey AS ExternOrderKey,
          @c_StorerKey AS Storerkey,
          MAX(ISNULL(RTRIM(ST.Company), ''))  AS ST_Company,
          ''  AS ReprintFlag,
          @c_PickSlipNo AS PickSlipNo,
          @c_Company, 
          @c_Address1,
          @c_Address2,
          @c_Address3,
          @c_Address4,
          @c_City,    
          @c_STATE,   
          @c_Country, 
          @c_Contact1,
          @c_Phone1, 
          @c_BuyerPO,
          ISNULL(PD.CartonNo, 0)         AS CartonNo,
          ISNULL(RTRIM(S.Style), '')     AS Style,
          CASE WHEN ISNULL(@c_colorsize_busr67,'') = '1' THEN
                 LEFT(ISNULL(S.Busr6,''),10)
               ELSE
                 ISNULL(RTRIM(S.Color),'') END AS Color,
          MAX(PH.LoadKey)
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   JOIN STORER ST WITH (NOLOCK)  ON  (ST.StorerKey = OH.Storerkey)
   JOIN PackDetail PD WITH (NOLOCK) ON  (PD.PickSlipNo = PH.PickSlipNo)
   JOIN SKU S WITH (NOLOCK) ON  (S.Storerkey = PD.Storerkey) AND (S.Sku = PD.Sku)
   WHERE PH.PickSlipNo = @c_PickSlipNo 
   GROUP BY ISNULL(RTRIM(S.Style), '')
          , CASE WHEN ISNULL(@c_colorsize_busr67,'') = '1' 
                 THEN LEFT(ISNULL(S.Busr6,''),10)
                 ELSE ISNULL(RTRIM(S.Color),'') END
          , ISNULL(PD.CartonNo, 0)
   
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
      IF ISNULL(@c_colorsize_busr67,'') = '1'
      BEGIN
         DECLARE SIZE_CUR CURSOR FAST_FORWARD READ_ONLY 
         FOR
            SELECT CASE WHEN CHARINDEX('|',S.Busr7) > 0 THEN
                               LEFT(S.BUSR7, CHARINDEX('|',S.BUSR7)-1)
                          ELSE LEFT(ISNULL(S.Busr7,''),4) END AS Size,
                     ISNULL(PD.Qty, 0)
            FROM PackDetail PD WITH (NOLOCK)
            JOIN SKU S WITH (NOLOCK) ON  (S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU)
            WHERE PD.PickSlipNo = @c_PickSlipNo
            AND PD.CartonNo = @n_CartonNo
            AND S.Style = @c_Style
            AND LEFT(ISNULL(S.Busr6,''),10) = @c_Color
            ORDER BY 1
      END
      ELSE
      BEGIN
         DECLARE SIZE_CUR CURSOR FAST_FORWARD READ_ONLY 
         FOR
            SELECT CASE WHEN ISNULL(C.short,'')='Y' THEN                                               
                   CASE WHEN S.measurement IN ('','U') THEN SUBSTRING(ISNULL(RTRIM(S.Size), ''), 1, 4) 
                                                        ELSE ISNULL(S.measurement,'') END             
                   ELSE S.Size END [Size] ,                                                            
                   ISNULL(PD.Qty, 0)
            FROM   PackDetail PD WITH (NOLOCK)
            JOIN SKU S WITH (NOLOCK) ON  (S.Storerkey = PD.Storerkey AND S.SKU = PD.SKU)
            LEFT JOIN CODELKUP C WITH (nolock) ON C.storerkey= PD.Storerkey  
                                              AND listname = 'REPORTCFG' and code ='GetSkuMeasurement'        
                                              AND long='r_dw_packing_list_102'
            WHERE  PD.PickSlipNo = @c_PickSlipNo
            AND PD.CartonNo = @n_CartonNo
            AND S.Style = @c_Style
            AND S.Color = @c_Color
            ORDER BY SUBSTRING(s.size, 1, 4)
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
          WHERE  Pickslipno = @c_PickSlipNo
          GROUP BY PickSlipNo
        ) AS PD ON  (PD.PickSlipNo = TP.PickSlipNo) 
   
   SELECT DISTINCT
          ISNULL(RTRIM(Loadkey), ''),
          ISNULL(RTRIM(Storerkey), ''),
          ISNULL(RTRIM(ST_Company), ''),
          ISNULL(RTRIM(PickSlipNo), ''),
          ISNULL(RTRIM(Company), ''),
          ISNULL(RTRIM(address1), ''),
          ISNULL(RTRIM(address2), ''),
          ISNULL(RTRIM(address3), ''),
          ISNULL(RTRIM(address4), ''),
          ISNULL(RTRIM(City), ''),
          ISNULL(RTRIM([STATE]), ''),
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
          ISNULL(RTRIM(ExternOrderkey), '') 
   FROM #TempNPPL
   ORDER BY ISNULL(RTRIM(PickSlipNo), ''),
            ISNULL(RTRIM(Storerkey), ''),
            ISNULL(CartonNo, 0),
            ISNULL(RTRIM(Style), ''),
            ISNULL(RTRIM(Color), '') 

EXIT_SP:
   IF OBJECT_ID('tempdb..#TempNPPL') IS NOT NULL
      DROP TABLE #TempNPPL 

   IF OBJECT_ID('tempdb..#TMP_CTN') IS NOT NULL
      DROP TABLE #TMP_CTN 

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
END  

GO