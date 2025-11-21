SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_packing_list_23_rpt                                */
/* Creation Date: 11-Aug-2016                                              */
/* Copyright: LF                                                           */
/* Written by: CSCHONG                                                     */
/*                                                                         */
/* Purpose:  SOS#374228 -CN Carter's Wholesale Packing list                */
/*                                                                         */
/* Called By: PB: r_dw_packing_list_23_rpt                                 */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/***************************************************************************/
CREATE PROC [dbo].[isp_packing_list_23_rpt]
           @c_Orderkey    NVARCHAR(10) 

AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_Storerkey       NVARCHAR(15)
   
   
   
      CREATE TABLE #TMP_PackingList23
            (  Orderkey                  NVARCHAR(50) DEFAULT ('')
            ,  loadkey                   NVARCHAR(20) DEFAULT ('')
            ,  wavekey                   NVARCHAR(20) DEFAULT ('')
            ,  CartonNo                  INT
            ,  AltSKU                    NVARCHAR(20) DEFAULT ('')
            ,  SKU                       NVARCHAR(20)DEFAULT ('')
            ,  S_SIZE                    NVARCHAR(10) DEFAULT ('')
            ,  labelno                   NVARCHAR(20) DEFAULT ('')
            ,  PWeight                   INT
            ,  PQty                      INT
            )
   INSERT INTO #TMP_PackingList23 (Orderkey                  
											,  loadkey                   
											,  wavekey                   
											,  CartonNo                  
											,  AltSKU                    
											,  SKU                      
											,  S_SIZE                    
											,  labelno                   
											,  PWeight                   
											,  PQty 
											)
      SELECT DISTINCT ORD.OrderKey,ORD.LoadKey,PDET.WaveKey,PD.CartonNo,
		S.ALTSKU,s.Sku,size,pd.LabelNo,sum(pif.weight),sum(pd.qty)
		FROM PACKHEADER PH WITH (NOLOCK)
		JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
		JOIN PICKDETAIL PDET WITH (NOLOCK) ON PDET.CaseID=PD.LabelNo
		JOIN Orders ORD WITH (NOLOCK) ON Ord.OrderKey=PDET.OrderKey
		--LEFT JOIN WAVEDETAIL AS WD WITH (NOLOCK) ON WD.OrderKey = PH.OrderKey 
		JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey=PD.StorerKey
		JOIN PackInfo AS pif WITH (NOLOCK) ON pif.PickSlipNo=pd.PickSlipNo AND pif.cartonno = pd.CartonNo
		WHERE ORD.OrderKey=@c_Orderkey
		GROUP BY  ORD.OrderKey,ORD.LoadKey,PDET.WaveKey,PD.CartonNo,
		S.ALTSKU,s.Sku,size,pd.LabelNo
  

  SELECT * FROM #TMP_PackingList23 
  ORDER BY orderkey,CartonNo

END

SET QUOTED_IDENTIFIER OFF 

GO