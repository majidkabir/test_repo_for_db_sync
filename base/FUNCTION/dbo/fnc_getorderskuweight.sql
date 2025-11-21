SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Function       : fnc_GetOrderSkuWeight                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Calculate Sum Order's SKU Weight                            */
/*                                                                      */
/* Usage: Select fnc_GetOrderSkuWeight (@c_orderkey)                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2018-01-29   1.0  TLTING     Copy from LocalCN version               */
/************************************************************************/


CREATE   FUNCTION [dbo].[fnc_GetOrderSkuWeight](@c_OrderKey   NVARCHAR(10), @c_mode NCHAR(1))   
  RETURNS FLOAT
  AS    
  BEGIN  
  DECLARE   @n_TotalWeight    FLOAT  = '0'

  IF @c_mode = '1'
  BEGIN
  
     SELECT @n_TotalWeight = ISNULL(SUM(ISNULL(s.STDGROSSWGT,0)*pd.Qty) , 0)
     FROM dbo.PICKDETAIL (NOLOCK) pd 
     INNER JOIN dbo.SKU (NOLOCK) s ON s.StorerKey = pd.Storerkey AND s.Sku = pd.Sku 
     WHERE pd.OrderKey = @c_OrderKey
     END

   ELSE IF @c_mode = '2'
   BEGIN
  
     SELECT @n_TotalWeight = ISNULL(SUM(ISNULL(s.STDGROSSWGT,0)*pd.Qty) , 0)
     FROM dbo.PICKDETAIL (NOLOCK) pd 
     INNER JOIN dbo.SKU (NOLOCK) s ON s.StorerKey = pd.Storerkey AND s.Sku = pd.Sku 
     WHERE pd.OrderKey = @c_OrderKey
     AND pd.status = '5' 
   END
   ELSE IF @c_mode = '3'
   BEGIN
     SELECT @n_TotalWeight = ( ( SELECT  ISNULL(SUM(ISNULL(s.STDGROSSWGT,0)*pd.Qty) , 0)
     FROM dbo.PICKDETAIL (NOLOCK) pd 
     INNER JOIN dbo.SKU (NOLOCK) s ON s.StorerKey = pd.Storerkey AND s.Sku = pd.Sku 
     WHERE pd.OrderKey = @c_OrderKey
     AND pd.status = '5'  )
     +
      (SELECT ISNULL(SUM(C.CartonWeight ), 0)
      FROM PackHeader PH (NOLOCK) 
      JOIN Storer S (NOLOCK) ON PH.Storerkey = S.Storerkey
      JOIN PackInfo PI (NOLOCK) ON PH.PickSlipNo = PI.PickSlipNo 
      JOIN Cartonization C (NOLOCK) ON C.CartonType = PI.CartonType AND C.CartonizationGroup = S.CartonGroup
      WHERE PH.Orderkey = @c_OrderKey) ) 

   END
   
  RETURN   @n_TotalWeight
  END 


GO