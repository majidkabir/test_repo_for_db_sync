SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_JDSPORT_Daily_Outbound_Dashboard] AS
SELECT
   O.StorerKey,
   O.Facility,
   CONVERT (Date, O.OrderDate ) AS 'OrderDate',
   OD.OrderKey,
   O.ExternOrderKey,
   O.ConsigneeKey,
   O.C_Company,
   Sum(OD.OriginalQty) AS 'TotalOrderQTY',
   isnull ((
   select
      sum(PD.qty)
   from
      pickdetail PD with (nolock)
   where
      PD.orderkey =
      (
         OD.OrderKey
      )
), 0) AS 'AllocateOrPickedQty',
      isnull ((
      Select
         sum(a.qty)
      from
         Packdetail a with (nolock)
      where
         a.Pickslipno in
         (
            Select
               b.Pickslipno
            from
               Packheader b with (nolock)
            where
               b.Storerkey = O.StorerKey
               and b.Orderkey =
               (
                  OD.OrderKey
               )
         )
), 0) AS 'PackQTY',
         Sum(OD.ShippedQty) AS 'ShippedQTY',
         O.Status,
         isnull ((
         select
            max(PH.status)
         from
            packheader PH with (nolock)
         where
            PH.orderkey =
            (
               OD.OrderKey
            )
), 0)AS 'PackStatus',
            O.Notes2
         FROM
            dbo.ORDERS O with (nolock)
         JOIN dbo.ORDERDETAIL OD with (nolock) ON O.OrderKey = OD.OrderKey
               AND O.StorerKey = OD.StorerKey
         WHERE
            (
(O.StorerKey = 'JDSPORTS'
               AND
               (
                  O.OrderDate >= Convert(VarChar(10), GetDate() - 32, 121)
                  and O.OrderDate < Convert(VarChar(10), GetDate(), 121)
               )
)
            )
         GROUP BY
            O.StorerKey,
            O.Facility,
            CONVERT (Date, O.OrderDate ),
            OD.OrderKey,
            O.ExternOrderKey,
            O.ConsigneeKey,
            O.C_Company,
            O.Status,
            O.Notes2

GO