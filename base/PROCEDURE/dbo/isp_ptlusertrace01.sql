SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_PTLUserTrace01                                  */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: PTS User Action Trace                                       */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 02-10-2014 1.0  ChewKP   Created.                                    */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_PTLUserTrace01] (  
     @cUserName            NVARCHAR(18)   
    ,@cStorerKey           NVARCHAR( 15)   
    ,@cWaveKey             NVARCHAR(10)  
 )  
AS  
BEGIN  
     
    SET NOCOUNT ON  
    SET QUOTED_IDENTIFIER OFF  
    SET ANSI_NULLS OFF  
    SET CONCAT_NULL_YIELDS_NULL OFF  
      
      
      
      
    SELECT PTL.AddWho, DP.DeviceID AS PTSLocation  
         , CASE WHEN PTL.Remarks <> '' THEN '' ELSE PTL.DropID END  AS ZoneLabel  
         , CASE WHEN PTL.Remarks <> '' THEN '' ELSE PTL.SKU END  AS SKU  
         , CASE WHEN PTL.Remarks <> '' THEN '' ELSE PTL.Status END AS Status   
         , CASE WHEN PTL.Remarks <> '' THEN '' ELSE PTL.ExpectedQty END AS ExpectedQty  
         , CASE WHEN PTL.Remarks <> '' THEN '' ELSE PTL.Qty  END AS Qty  
         , CASE WHEN PTL.Remarks = 'HOLD' THEN PTL.Remarks   
                WHEN PTL.Remarks = 'END' THEN PTL.Remarks   
                WHEN PTL.Remarks = 'FULL' THEN PTL.Remarks   
                WHEN PTL.Remarks <> '' THEN 'NEXT LOC ' + PTL.Remarks   
                ELSE ''   
                END AS Remarks  
           
   FROM dbo.PTLTRAN PTL (NOLOCK)   
   INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON O.OrderKey = PTL.Orderkey  
   INNER JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DP.DevicePosition = PTL.DevicePosition  
   WHERE O.UserDefine09 = @cWaveKey  
   AND PTL.AddWho = @cUserName  
   AND DP.Priority = '1'   
   AND PTL.StorerKey = @cStorerKey  
   ORDER BY PTL.MessageNum, PTL.Editdate DESC, PTL.DeviceProfileLogKey  
      
      
  
END  

GO