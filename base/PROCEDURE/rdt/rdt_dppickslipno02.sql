SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_DPPickslipNo02                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get Pick Slip No thru customized stored proc                */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2013-07-09 1.0  ChewKP   SOS#281897 - TBL Enhancement (ChewKP01)     */
/* 2014-03-21 1.1  TLTING   SQL2005                                     */
/* 2014-02-05 1.1  ChewKP   Insert PackHeader When Not Exists (ChewKP02)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_DPPickslipNo02] (
   @c_WaveKey       NVARCHAR( 10),
   @c_OrderKey      NVARCHAR( 10),
   @c_PickDetailKey NVARCHAR( 10) = '',
   @c_PickHeaderKey NVARCHAR( 10) OUTPUT
) AS 

BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickSlipNo AS NVARCHAR(10)
          ,@b_success    AS INT
          ,@n_err        AS INT
          ,@c_errmsg     AS NVARCHAR(20) 

   SELECT @c_PickHeaderKey = PH.PickHeaderKey
   FROM dbo.WaveDetail WD WITH (NOLOCK)
   --JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (WD.OrderKey = LPD.OrderKey)
   JOIN dbo.PickHeader PH WITH (NOLOCK) ON (WD.OrderKey = PH.OrderKey AND WD.WaveKey = PH.WaveKey)
   WHERE WD.WaveKey = @c_WaveKey
      AND WD.OrderKey = @c_OrderKey
      
   IF @@ROWCOUNT = 0 SET @c_PickHeaderKey = ''

   IF @c_PickHeaderKey = ''
   BEGIN
      
      SELECT @b_success = 0 
      
      EXECUTE nspg_getkey 
      'PICKSLIP' 
      , 9 
      , @c_PickSlipNo OUTPUT 
      , @b_success OUTPUT 
      , @n_err OUTPUT 
      , @c_errmsg OUTPUT 
      
      
      IF @b_success = 1
      BEGIN
         SELECT @c_PickSlipNo = 'P' + RTRIM(@c_PickSlipNo)
      END
      ELSE
      BEGIN
        SET @c_PickHeaderKey = ''
      END
      
      
      INSERT PickHeader
      (
      Pickheaderkey
      ,Wavekey
      ,Orderkey
      ,zone
      ,picktype
      )
      VALUES
      (
      @c_PickSlipNo
      ,@c_Wavekey
      ,@c_Orderkey
      ,'3'
      ,'0'
      )
      
      SET @c_PickHeaderKey = @c_PickSlipNo

   END
      
END

GO