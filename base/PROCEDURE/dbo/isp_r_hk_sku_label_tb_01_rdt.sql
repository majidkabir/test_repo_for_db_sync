SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_sku_label_tb_01_rdt                        */
/* Creation Date: 04-Oct-2018                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Pre-print Carton Label                                       */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_sku_label_tb_01_rdt         */
/*                                  and r_hk_sku_label_tb_02_rdt         */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 07/03/2019   ML       1.1  Change to use SEQKey table for SeqTbl      */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_sku_label_tb_01_rdt] (
       @as_storerkey       NVARCHAR(15)
     , @as_labelno         NVARCHAR(30)
     , @as_sku             NVARCHAR(20) = ''
     , @as_noofcopy        NVARCHAR(10) = ''
     , @as_LabelType       NVARCHAR(20)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ReportType         NVARCHAR(20)
         , @c_Conditions         NVARCHAR(MAX)
         , @c_ExecStatements     NVARCHAR(MAX)
         , @c_ExecArguments      NVARCHAR(MAX)


   SELECT TOP 1
          @c_ReportType = ISNULL(RTRIM(UDF01),'')
        , @c_Conditions = ISNULL(RTRIM(Notes2),'')
     FROM dbo.CODELKUP(NOLOCK)
    WHERE Listname  = 'TORYLBL'
      AND Storerkey = @as_storerkey
      AND Long      = @as_LabelType


   SET @c_ExecStatements =
         N'SELECT Storerkey   = X.Storerkey'
          +    ', LabelNo     = X.LabelNo'
          +    ', Sku         = X.Sku'
          +    ', Style       = X.Style'
          +    ', Qty         = X.Qty'
          +    ', Notes       = X.Notes'
          +    ', COO_Country = X.COO_Country'
          +    ', SeqNo       = SeqTbl.Rowref'
        +' FROM ('
          + ' SELECT Storerkey   = RTRIM(PD.Storerkey)'
          +       ', LabelNo     = RTRIM(PD.LabelNo)'
          +       ', Sku         = RTRIM(PD.Sku)'
          +       ', Style       = ISNULL(RTRIM(MAX(SKU.Style)),'''')'
          +       ', Qty         = ' + CASE WHEN ISNULL(@as_sku,'')<>'' AND TRY_PARSE(ISNULL(@as_noofcopy,'') AS INT)>0 THEN @as_noofcopy ELSE 'SUM(PD.Qty)' END
          +       ', Notes       = ISNULL(RTRIM(MAX(SKU.Notes2)),'''')'
          +       ', COO_Country = ISNULL(RTRIM(MAX(COO.COO_Country)),'''')'
   SET @c_ExecStatements = @c_ExecStatements
          + ' FROM dbo.PACKDETAIL PD(NOLOCK)'
          + ' JOIN dbo.SKU SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku'
          + ' JOIN ('
          +   ' SELECT Storerkey   = a.Storerkey'
          +         ', Sku         = a.Sku'
          +         ', DropID      = CASE WHEN a.CartonType=''FCP'' THEN a.AltSku ELSE a.DropID END'
          +         ', COO_Country = MAX(c.Description)'
          +   ' FROM dbo.PICKDETAIL a (NOLOCK)'
          +   ' JOIN dbo.LOTATTRIBUTE b(NOLOCK) ON a.Lot=b.Lot'
          +   ' JOIN dbo.CODELKUP c(NOLOCK) ON c.LISTNAME = ''TBCOUNTRY'' AND LEFT(b.Lottable03,2) = c.Code'
          +   ' WHERE a.Storerkey = @as_storerkey'
          +     ' AND ISNULL(CASE WHEN a.CartonType=''FCP'' THEN a.AltSku ELSE a.DropID END,'''')<>'''''
          +     ' AND ISNULL(c.Description,'''')<>'''''
          +   ' GROUP BY a.Storerkey, a.Sku, CASE WHEN a.CartonType=''FCP'' THEN a.AltSku ELSE a.DropID END'
          + ' ) COO ON PD.Storerkey = COO.Storerkey AND PD.Sku = COO.Sku AND IIF(ISNULL(PD.RefNo,'''')<>'''',PD.RefNo,PD.DropID) = COO.DropID'
          + ' LEFT JOIN dbo.SKUINFO SKUINFO(NOLOCK) ON PD.Storerkey=SKUINFO.Storerkey AND PD.Sku=SKUINFO.Sku'
          + ' WHERE PD.Storerkey = @as_storerkey'
          +   ' AND PD.LabelNo = @as_labelno'
          +   ' AND PD.Qty>0'
   SET @c_ExecStatements = @c_ExecStatements
          + CASE WHEN ISNULL(@as_sku,'')<>'' THEN ' AND PD.Sku = @as_sku' ELSE '' END
   SET @c_ExecStatements = @c_ExecStatements
          + CASE WHEN ISNULL(@c_Conditions,'')<>'' THEN ' AND (' + @c_Conditions + ')' ELSE '' END
   SET @c_ExecStatements = @c_ExecStatements
          + ' GROUP BY PD.Storerkey, PD.LabelNo, PD.Sku'
       + ' ) X'
       + ' JOIN dbo.SEQKey SeqTbl(NOLOCK) ON SeqTbl.Rowref <= X.Qty'
       + ' ORDER BY Storerkey, LabelNo, Sku, SeqNo'


   SET @c_ExecArguments = N'@as_storerkey NVARCHAR(15)'
                        +', @as_labelno NVARCHAR(30)'
                        +', @as_sku NVARCHAR(20)'
                        +', @as_noofcopy NVARCHAR(10)'
                        +', @as_LabelType NVARCHAR(20)'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @as_storerkey
                    , @as_labelno
                    , @as_sku
                    , @as_noofcopy
                    , @as_LabelType
END

GO