SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_Pallet_outboundlist04_rdt                           */
/* Creation Date: 18-JUL-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-2152 - CN_DYSON_Report_POD                              */
/*        :                                                             */
/* Called By:r_dw_pallet_outboundlist04_rdt                             */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 18-JUL-2023  CSCHONG   1.0 Devops Scripts Combine                    */
/************************************************************************/
CREATE   PROC [dbo].[isp_Pallet_outboundlist04_rdt]
           @c_PalletKey   NVARCHAR(30)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @c_PLTKey          NVARCHAR(30)
         , @c_storerkey       NVARCHAR(20)
         , @c_wavekey         NVARCHAR(20)
         , @c_loadkey         NVARCHAR(20)
         , @c_trfroom         NVARCHAR(20)
         , @n_TTLCase         INT
         , @c_caseid          NVARCHAR(20)  
         , @c_remarks         NVARCHAR(80)   =''      
         , @c_floor           NVARCHAR(5)

   SET @n_StartTCnt = @@TRANCOUNT

   SET @n_TTLCase = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

  SELECT @c_PLTKey = @c_PalletKey

  --SELECT TOP 1 @c_loadkey = PLD.UserDefine05
  --            ,@c_caseid = PLD.CaseId
  --FROM dbo.PALLETDETAIL PLD WITH (NOLOCK)
  --WHERE PLD.PalletKey = @c_PalletKey

  SELECT TOP 1 @c_loadkey = UDF01
  FROM DROPID WITH (NOLOCK)
  WHERE Dropid = @c_PalletKey


  --SELECT @n_TTLCase= COUNT(DISTINCT PLD.CaseId)
  --FROM dbo.PALLETDETAIL PLD WITH (NOLOCK)
  --WHERE PLD.UserDefine05 = @c_loadkey 

  SELECT @n_TTLCase= COUNT(DISTINCT ChildId)
  FROM dbo.DropidDetail  WITH (NOLOCK)
  WHERE Dropid = @c_PalletKey


   SELECT TOP 1 @c_wavekey = OH.userdefine09
   FROM dbo.ORDERS OH WITH (NOLOCK)
   WHERE OH.LoadKey = @c_loadkey

   SELECT @c_trfroom = LP.trfroom
   FROM dbo.LoadPlan LP WITH (NOLOCK)
   WHERE LP.LoadKey = @c_loadkey

  SET @c_floor =''

  SELECT TOP 1 @c_floor = Loc.Floor 
  FROM Loc WITH (NOLOCK)
  JOIN PickDetail WITH (NOLOCK) ON Loc.Loc=PickDetail.Loc
  JOIN OrderDetail WITH (NOLOCK) ON OrderDetail.OrderKey=PickDetail.OrderKey
  JOIN LoadPlanDetail WITH (NOLOCK) ON LoadPlanDetail.OrderKey=OrderDetail.OrderKey
  Join Dropid WITH (NOLOCK) ON Dropid.UDF01=LoadPlanDetail.Loadkey
  WHERE Dropid.Dropid= @c_PalletKey
  AND  Loc.Floor<> '3'


  IF ISNULL(@c_floor,'0') = '1'
  BEGIN
    SET @c_remarks = N'*需與一樓合併'
  END


   SELECT DISTINCT DP.Dropid AS palletkey
          , @c_wavekey AS ohudf09
          , @c_loadkey AS Loadkey
          , @c_trfroom AS TrfRoom
          , DPD.ChildId AS ToteID
          , @n_TTLCase as TTLCase
          , @c_remarks AS Remarks
          ,N'棧板編號' AS title1
          ,N'箱號' AS Title2
  FROM dbo.Dropid DP WITH (NOLOCK)
  JOIN dbo.DropidDetail DPD WITH (NOLOCK) ON DPD.Dropid=DP.Dropid
  WHERE DP.UDF01 = @c_loadkey
 ORDER BY DP.Dropid,DPD.ChildId

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO