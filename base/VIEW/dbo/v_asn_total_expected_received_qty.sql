SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW dbo.V_ASN_Total_Expected_Received_Qty AS
SELECT
    ReceiptKey,
    SUM(QtyExpected) AS TotalExpectedQty,
    SUM(QtyReceived+BeforeReceivedQty)  AS TotalReceivedQty
FROM
    RECEIPTDETAIL WITH (NOLOCK)
GROUP BY
    ReceiptKey;

GO