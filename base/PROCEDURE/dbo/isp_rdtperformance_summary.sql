SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: isp_RDTPerformance_Summary                            */
/* Copyright      : IDS                                                   */
/*                                                                        */
/* Purpose: Trace top 5 worse performance of the day from rdtTraceSummary */
/*          in DataMart DB                                                */
/*                                                                        */
/*                                                                        */
/* Modifications log:                                                     */
/*                                                                        */
/* Date       Rev  Author      Purposes                                   */
/* 2009-03-30 1.0  Vicky       Created                                    */
/* 2009-06-15 1.1  Vicky       Change DateTime format                     */ 
/**************************************************************************/

CREATE PROC [dbo].[isp_RDTPerformance_Summary]
AS
BEGIN
    SET NOCOUNT ON

    SELECT TOP 10 Country, CONVERT(char(10), Transdate, 120) as TransDate, InFunc, InStep, OutStep,  
    (SELECT DISTINCT storedprocname FROM RDT.RDTMsg WITH (NOLOCK) WHERE infunc = message_id and Lang_Code = 'ENG') Storproc,
     SUM(MS1000_2000 + MS2000_5000 + MS5000_UP) AS #_Trans_More_than_1s,
--     SUM(MS0_1000) AS MS0_1000,
--     SUM(MS1000_2000) AS MS1000_2000,
--     SUM(MS2000_5000) AS MS2000_5000,
--     SUM(MS5000_UP) AS MS5000_UP,
    SUM(MS0_1000 + MS1000_2000 + MS2000_5000 + MS5000_UP) AS Total_#_Of_Trans,
    (SUM(MS1000_2000 + MS2000_5000 + MS5000_UP)*100/SUM(MS0_1000 + MS1000_2000 + MS2000_5000 + MS5000_UP)) as 'Percentage(%)'
    FROM RDTTraceSummary WITH (NOLOCK)
    WHERE Infunc > 1
    AND InStep > 0
    AND Transdate >= Convert(char(10), getdate()-1, 103)
    AND Transdate <= Convert(char(10), getdate()-1, 103)
    GROUP BY Country, InFunc, InStep, OutStep, transdate
    HAVING (SUM(MS1000_2000 + MS2000_5000 + MS5000_UP)*100/SUM(MS0_1000 + MS1000_2000 + MS2000_5000 + MS5000_UP))  > 1 -- #_Trans_More_than_1s/Total_#_Of_Trans > 1% (Vicky03)
    AND SUM(MS0_1000 + MS1000_2000 + MS2000_5000 + MS5000_UP) > 200 -- (Vicky01)
    ORDER BY Country, SUM(MS0_1000 + MS1000_2000 + MS2000_5000 + MS5000_UP), (SUM(MS1000_2000 + MS2000_5000 + MS5000_UP)*100/SUM(MS0_1000 + MS1000_2000 + MS2000_5000 + MS5000_UP)) DESC
 
    SET NOCOUNT OFF
END


GO