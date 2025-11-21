SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: isp_RDTPerformance                                    */
/* Copyright      : IDS                                                   */
/*                                                                        */
/* Purpose: Trace top 5 worse performance of the day                      */
/*                                                                        */
/* PVCS Version: 1.0                                                      */
/*                                                                        */
/* Modifications log:                                                     */
/*                                                                        */
/* Date       Rev  Author      Purposes                                   */
/* 2008-10-28 1.0  Vicky       Created                                    */
/* 2008-11-11 1.1  Vicky       Add filtering of Lang_Code to get SP name  */  
/* 2008-11-25 1.2  Vicky       Only show Total_#_Of_Trans > 100 (Vicky01) */
/* 2008-12-02 1.3  Vicky       InFunc should be > 1 (Vicky02)             */
/* 2009-03-26 1.4  Vicky       Get Information up to MS5000_UP            */ 
/*                             Change Percentage > 1 (Vicky03)            */
/**************************************************************************/

CREATE PROC [dbo].[isp_RDTPerformance]
AS
BEGIN
    SET NOCOUNT ON

    SELECT TOP 5 Transdate, InFunc, InStep, OutStep,  
    (SELECT DISTINCT storedprocname FROM RDT.RDTMsg WITH (NOLOCK) WHERE infunc = message_id and Lang_Code = 'ENG') Storproc,
    SUM(MS1000_2000 + MS2000_5000 + MS5000_UP) AS #_Trans_More_than_1s,
    SUM(MS0_1000 + MS1000_2000 + MS2000_5000 + MS5000_UP) AS Total_#_Of_Trans,
    (SUM(MS1000_2000 + MS2000_5000 + MS5000_UP)*100/SUM(MS0_1000 + MS1000_2000 + MS2000_5000 + MS5000_UP)) as 'Percentage(%)'
    FROM RDT.V_RDT_TIMINGS_DETAIL WITH (NOLOCK)
    WHERE Infunc > 1 -- (Vicky02) 
    AND InStep > 0
    AND Transdate >= Convert(char(10), getdate()-1, 120)
    AND Transdate <= Convert(char(10), getdate()-1, 120)
    GROUP BY InFunc, InStep, OutStep, transdate
    HAVING (SUM(MS1000_2000 + MS2000_5000 + MS5000_UP)*100/SUM(MS0_1000 + MS1000_2000 + MS2000_5000 + MS5000_UP))  > 1 -- #_Trans_More_than_1s/Total_#_Of_Trans > 1% (Vicky03)
    AND SUM(MS0_1000 + MS1000_2000 + MS2000_5000 + MS5000_UP) > 100 -- (Vicky01)
    ORDER BY (SUM(MS1000_2000 + MS2000_5000 + MS5000_UP)*100/SUM(MS0_1000 + MS1000_2000 + MS2000_5000 + MS5000_UP)) DESC
 
    SET NOCOUNT OFF

END


GO