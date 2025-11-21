SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_PalletDetail_LOGITECH]
AS
WITH PalletDetail2 AS
(
Select PD.Palletkey, O.MBOLKey, PD.UserDefine02, O.ExternOrderkey, O.C_Company
From dbo.PALLETDETAIL PD (nolock)
LEFT JOIN dbo.ORDERS O (NOLOCK) ON O.OrderKey = PD.UserDefine02 and O.StorerKey = 'LOGITECH'
where PD.Storerkey = 'LOGITECH' --and PalletKey = 'AP074275'
Group By PD.Palletkey, O.MBOLKey, PD.UserDefine02, O.ExternOrderkey, O.C_Company
),

PalletDetail3 AS
(
Select ROW_NUMBER() OVER (PARTITION BY Palletkey Order BY UserDefine02 DESC) as RN, Palletkey, MBOLKey, UserDefine02,
STUFF((SELECT '; ' + RTRIM(PD3.ExternOrderkey )
    FROM PalletDetail2 PD3
    WHERE PD.Palletkey = PD3.Palletkey
    FOR XML PATH('')),1,1,'') AS ExternOrderkey, PD.C_Company From PalletDetail2 PD (nolock)-- where pd.PalletKey = 'AP074275'
  group by Palletkey, MBOLKey, UserDefine02, ExternOrderkey, C_Company
)
--select * From PalletDetail3 PD (nolock)
Select ROW_NUMBER() OVER(PARTITION BY PD.MBOLKey ORDER BY PD.MBOLKey) AS PalletNO, PD.PalletKey, PD.MBOLKey, P.PalletType, PD.UserDefine02, P.Length, P.Width, P.Height
,CBM= (P.Length*P.Width* P.Height)/1000000
, P.GrossWgt, LLI.LOC, PD.ExternOrderKey, PD.C_Company
From PalletDetail3 PD (nolock)
JOIN dbo.PALLET P (nolock) ON P.PalletKey = PD.PalletKey
JOIN (select DISTINCT LOC, ID FROM dbo.LOTxLOCxID (nolock) where StorerKey = 'LOGITECH') AS LLI ON LLI.Id = PD.PalletKey
where P.StorerKey = 'LOGITECH' and pd.rn = 1-- and mbolkey = '0000606408'
group by PD.PalletKey, PD.MBOLKey, P.PalletType, PD.UserDefine02, P.Length, P.Width, P.Height, P.GrossWgt, LLI.LOC, PD.ExternOrderKey, PD.C_Company


GO