SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: fnc_GetWaveOrder_DropID                                     */
/* Creation Date: 28-APR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1466 - CN & SG Logitech - Packing                       */
/*        :                                                             */
/*                                                                      */
/* Called By:  isp_DropID_GetPackSku                                    */
/*          :  isp_DropID_Insert_Packing                                */
/*          :                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-05-09  Wan01    1.1   DevOps Combine Script                     */
/* 2022-05-09  Wan01    1.1   Performance Tune                          */
/************************************************************************/
CREATE   FUNCTION [dbo].[fnc_GetWaveOrder_DropID] 
  ( 
     @c_DropID    NVARCHAR(20)
  )
RETURNS @t_OrderWave TABLE   
(     RowNo       INT         IDENTITY (1,1) PRIMARY KEY
   ,  Wavekey     NVARCHAR(10) NOT NULL  
   ,  Orderkey    NVARCHAR(10) NOT NULL 
   ,  Storerkey   NVARCHAR(15) NOT NULL   
   ,  OrderGroup  NVARCHAR(10) NOT NULL 
)     
AS
BEGIN
   --SET ANSI_NULLS OFF                                                                               --(Wan01)
   --SET QUOTED_IDENTIFIER OFF                                                                        --(Wan01)
   
   DECLARE @c_Wavekey   NVARCHAR(10)
         , @c_Orderkey  NVARCHAR(10)

   -- 1) Get Wavekey that pack in progress
   -- 2) Get Wavekey that not start packing yet
   SET @c_Wavekey = ''
   SELECT TOP 1 @c_Wavekey = WD.Wavekey
   FROM PICKDETAIL PD WITH (NOLOCK) 
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PD.OrderKey = WD.Orderkey)
   LEFT JOIN PACKHEADER PH WITH (NOLOCK) ON (WD.OrderKey = PH.Orderkey) AND PH.Orderkey <> ''         --(Wan01)
   WHERE PD.DropID = @c_DropID
   AND   PD.Status < '9'
   AND   PD.ShipFlag <> 'Y'
   AND   ISNULL(PH.Status,'0') < '9'
   ORDER BY PH.PickSlipNo DESC

   IF @c_Wavekey = ''
   BEGIN
      -- Get Wavekey for last Packing where order status < '9'
      SET @c_Orderkey = ''
      SELECT TOP 1 @c_Orderkey = PH.Orderkey
      FROM PACKHEADER PH WITH (NOLOCK) 
      JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
      WHERE PD.DropID = @c_DropID
      ORDER BY PH.PickSlipNo DESC

      IF EXISTS ( SELECT 1
                  FROM ORDERS WITH (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND   Status < '9'
                )
      BEGIN
         SELECT @c_Wavekey = Wavekey
         FROM WAVEDETAIL WITH (NOLOCK)
         WHERE Orderkey = @c_Orderkey
      END
   END

   IF @c_Wavekey <> '' 
   BEGIN
      INSERT INTO @t_OrderWave
         (  Wavekey
         ,  Orderkey
         ,  Storerkey
         ,  OrderGroup
         )
      SELECT DISTINCT 
             Wavekey = @c_Wavekey
            ,OH.Orderkey
            ,OH.Storerkey
            ,OH.OrderGroup
      FROM ORDERS     OH WITH (NOLOCK)
      JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
      WHERE OH.UserDefine09 = @c_Wavekey
      AND   PD.DropID = @c_DropID
   END

   RETURN
END 

GO