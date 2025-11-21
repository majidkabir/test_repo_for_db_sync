SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_RDTPPA]
AS
SELECT     PPA.RowRef, PPA.Refkey, PPA.PickSlipno, PPA.LoadKey, PPA.Store, PPA.StorerKey, PPA.Sku, PPA.Descr,
                      CASE rUser.DefaultUOM WHEN '1' THEN 'Pallet' WHEN '2' THEN 'Carton' WHEN '3' THEN 'Inner Pack' WHEN '4' THEN 'Other Unit 1' WHEN '5' THEN 'Other Unit 2'
                       WHEN '6' THEN 'Each' ELSE 'Each' END AS UOM, PPA.UOMQty,
                      CASE WHEN PPA.PQty = 0 THEN 0 WHEN PPA.UOMQty = 0 THEN 0 ELSE ISNULL(PPA.PQty, 0) / ISNULL(PPA.UOMQty, 0) END AS PickQty_Pack,
                      PPA.PQty AS PickQty_EA, PPA.CQty AS CheckQty_Pack, PPA.CQty * PPA.UOMQty AS CheckQty_EA, PPA.Status, PPA.UserName, PPA.AddDate,
                      PPA.NoofCheck, PPA.OrderKey, PPA.DropID
FROM         RDT.RDTPPA AS PPA WITH (NOLOCK) LEFT OUTER JOIN
                      RDT.RDTUser AS rUSER WITH (NOLOCK) ON PPA.UserName = rUSER.UserName





GO