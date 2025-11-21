SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_Print_CartonLabel_02                           */
/* Creation Date: 04-AUG-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-23203  - TH-MPI Pre-Pick Carton Label - NEW             */
/*                                                                      */
/* Called By: PB - Loadplan & Report Modules                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 04-AUG-2023  CSCHONG  1.0  Devops Scripts Combine                    */
/************************************************************************/

CREATE   PROC [dbo].[isp_Print_CartonLabel_02] (
       @cLoadKey       NVARCHAR(10) = '',
       @cPickSlipNo    NVARCHAR(10) = '',
       @nNoOfCartons   int = 1
)
AS
BEGIN
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  


   DECLARE @n_continue    int,
           @c_errmsg      NVARCHAR(255),
           @b_success     int,
           @n_err         int,
           @b_debug       int

      DECLARE @n_cnt INT

      DECLARE @c_storerkey NVARCHAR(20)

  


   SELECT DISTINCT loadkey, orderkey, ExternOrderKey,ISNULL(BuyerPO,'') AS buyerpo
    FROM ORDERS WITH (NOLOCK)
    WHERE LoadKey = @cLoadKey
   ORDER BY loadkey,Orderkey,ExternOrderKey
END


GO